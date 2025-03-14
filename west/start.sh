#!/bin/bash
# Usage: start.sh
# Description:  Builds an ECK cluster in Kind 

echo -e "\n*** Deploy Kind Cluster ***"
kind create cluster
docker run -d --rm --name cloud-provider-kind --network kind \
-v /var/run/docker.sock:/var/run/docker.sock registry.k8s.io/cloud-provider-kind/cloud-controller-manager:v0.6.0

echo -e "\n*** Deploy ECK Operator ***"
helm repo add elastic https://helm.elastic.co
helm repo update elastic
helm install elastic-operator elastic/eck-operator -n elastic-system --create-namespace

echo -e "\n*** Deploy ElasticSearch + Kibana ***"
kubectl apply -f elastic

echo -e "\n*** Wait for ElasticSearch + Kibana to come online ***"
ES_STATUS=$(kubectl get elasticsearch -o=jsonpath='{.items[0].status.health}')
KB_STATUS=$(kubectl get kibana -o=jsonpath='{.items[0].status.health}')
while [[ $ES_STATUS != "green" ||  $KB_STATUS != "green" ]]
do  
  sleep 5
  ES_STATUS=$(kubectl get elasticsearch -o=jsonpath='{.items[0].status.health}')
  KB_STATUS=$(kubectl get kibana -o=jsonpath='{.items[0].status.health}')
done

kubectl get secret westcluster-es-transport-certs-public -o jsonpath='{.data.ca\.crt}' | base64 --decode > west-ca.crt
kubectl get secret westcluster-es-http-certs-public -o jsonpath='{.data.ca\.crt}' | base64 --decode > west-http-ca.crt


WEST_ELASTIC_IP=$(kubectl get service westcluster-es-http -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
WEST_KIBANA_IP=$(kubectl get service kibana-kb-http -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo -e "*** ElasticSearch endpoint: https://$WEST_ELASTIC_IP:9200 ***"
echo -e "*** Kibana endpoint: https://$WEST_KIBANA_IP:5601 ***"

echo -e "\n*** Create west_ccr index ***"
curl -s -k -u "elastic:elastic" "https://$WEST_ELASTIC_IP:9200/_bulk?pretty" \
  -H "Content-Type: application/json" \
  -d'
{ "index" : { "_index" : "west_ccr" } }
{"name": "Snow Crash", "author": "Neal Stephenson", "release_date": "1992-06-01", "page_count": 470}
{ "index" : { "_index" : "west_ccr" } }
{"name": "Revelation Space", "author": "Alastair Reynolds", "release_date": "2000-03-15", "page_count": 585}
' > /dev/null

echo -e "\n*** Create west_ccs index ***"
curl -s -k -u "elastic:elastic" "https://$WEST_ELASTIC_IP:9200/_bulk?pretty" \
  -H "Content-Type: application/json" \
  -d'
{ "index" : { "_index" : "west_ccs" } }
{"name": "1984", "author": "George Orwell", "release_date": "1985-06-01", "page_count": 328}
{ "index" : { "_index" : "west_ccs" } }
{"name": "Fahrenheit 451", "author": "Ray Bradbury", "release_date": "1953-10-15", "page_count": 227}
' > /dev/null