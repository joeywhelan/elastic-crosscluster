#!/bin/bash
docker compose up -d
docker cp east-es01-1:/usr/share/elasticsearch/config/certs/ca/ca.crt east-ca.crt
source .env

echo -e "\n*** ElasticSearch endpoint: https://$EAST_ELASTIC_IP:9200 ***"
echo -e "*** Kibana endpoint: http://$EAST_KIBANA_IP:5601 ***"

echo -e "\n*** Create east_ccs index ***"
curl -s -k -u "elastic:elastic" "https://$EAST_ELASTIC_IP:9200/_bulk?pretty" \
  -H "Content-Type: application/json" \
  -d'
{ "index" : { "_index" : "east_ccs" } }
{"name": "Brave New World", "author": "Aldous Huxley", "release_date": "1932-06-01", "page_count": 268}
{ "index" : { "_index" : "east_ccs" } }
{"name": "The Handmaid'"'"'s Tale", "author": "Margaret Atwood", "release_date": "1985-06-01", "page_count": 311}
' > /dev/null