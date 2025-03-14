from elasticsearch import Elasticsearch

WEST_IP = "172.18.0.4"  # change this to match the external IP assigned to westcluster-es-http

client = Elasticsearch(f"https://{WEST_IP}:9200", ca_certs="../../west/west-http-ca.crt", basic_auth=("elastic", "elastic"))
resp = client.search(index=["west_ccs", "east_remote:east_ccs"], query={"range": {"release_date": {"gte": 1985}}})
for hit in resp["hits"]["hits"]:
    print(hit["_source"])
