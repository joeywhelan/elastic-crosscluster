#!/bin/bash
# Usage: start.sh
# Description:  Orchestrates the build of 2 ES clusters: one in K8s, the other in Docker.

echo -e "\n*** Deploy West Cluster ***"
cd west
./start.sh
cd - > /dev/null
echo -e "\n*** Deploy East Cluster ***"
cd east
./start.sh
cd - > /dev/null

echo -e "\n*** Configure Cross Cluster Replication - East leader, West follower ***"
source east/.env
echo -e "\n*** Connect Networks ***"
docker network connect kind east-es01-1
docker network connect east_net kind-control-plane

echo -e "\n*** Add East CA to West Cluster ***"
kubectl create configmap remote-certs --from-file=ca.crt=./east/east-ca.crt
kubectl patch elasticsearch westcluster --type=merge --patch '{"spec":{"transport":{"tls":{"certificateAuthorities":{"configMapName":"remote-certs"}}}}}'

echo -e "\n*** Activate West as a Remote Cluster on East ***"
WEST_TRANS_IP=$(kubectl get service westcluster-es-transport -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
json=$(jq -nc \
--arg proxy_address "$WEST_TRANS_IP":9300 \
'{
  persistent: {
    cluster: {
      remote: {
        west_remote: {
          mode: "proxy", 
          proxy_address: $proxy_address
        }
      }
    }
  }
}')
curl -s -k -u "elastic:elastic" -X PUT "https://$EAST_ELASTIC_IP:9200/_cluster/settings" \
  -H "Content-Type: application/json" \
  -d "$json" > /dev/null
REMOTE_STATUS=$(curl -s -k -u "elastic:elastic" "https://$EAST_ELASTIC_IP:9200/_resolve/cluster/west_remote:*" | jq '.west_remote.connected')
while [[ $REMOTE_STATUS != "true" ]]
do  
  sleep 5
  REMOTE_STATUS=$(curl -s -k -u "elastic:elastic" "https://$EAST_ELASTIC_IP:9200/_resolve/cluster/west_remote:*" | jq '.west_remote.connected')
done

echo -e "\n*** Create a Follower Index, east_ccr on East Cluster ***"
json=$(jq -nc \
'{
  remote_cluster: "west_remote",
  leader_index: "west_ccr",
  max_read_request_operation_count: 5120,
  max_outstanding_read_requests: 12,
  max_read_request_size: "32mb",
  max_write_request_operation_count: 5120,
  max_write_request_size: "9223372036854775807b",
  max_outstanding_write_requests: 9,
  max_write_buffer_count: 2147483647,
  max_write_buffer_size: "512mb",
  max_retry_delay: "500ms",
  read_poll_timeout: "1m"
}')

curl -s -k -u "elastic:elastic" -X PUT "https://$EAST_ELASTIC_IP:9200/east_ccr/_ccr/follow" \
  -H "Content-Type: application/json" \
  -d "$json" > /dev/null

echo -e "\n*** Enable Cross Cluster Search ***"
echo -e "\n*** Activate East as a Remote Cluster on West ***"

json=$(jq -nc \
--arg proxy_address "$EAST_ELASTIC_IP":9300 \
'{
  persistent: {
    cluster: {
      remote: {
        east_remote: {
          mode: "proxy", 
          proxy_address: $proxy_address
        }
      }
    }
  }
}')
WEST_ELASTIC_IP=$(kubectl get service westcluster-es-http -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -s -k -u "elastic:elastic" -X PUT "https://$WEST_ELASTIC_IP:9200/_cluster/settings" \
  -H "Content-Type: application/json" \
  -d "$json" > /dev/null