Elasticsearch's (ES) cross-cluster capabilities provide robust solutions for organizations aiming to scale, ensure data redundancy, and optimize search functionalities in multi-cluster environments. This article delves into the practical implementation of ES cross-cluster functionality, focusing on the establishment of two clusters, and the subsequent configuration of cross-cluster replication ([CCR](https://www.elastic.co/guide/en/elasticsearch/reference/current/xpack-ccr.html)) and cross-cluster search ([CCS](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-cross-cluster-search.html)).

## Multi-cluster Architecture ##
We'll be building a two-cluster architecture that utilizes two different deployment strategies:  Elastic Cloud on Kubernetes ([ECK](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-overview.html)) and Elasticsearch on Docker.  Both of these are supported production cluster architectures; however, the environments we are building here are scaled-down versions suitable for deployment on a laptop.  Ubuntu 24.04 is the O/S used for this laptop deployment.

### West Cluster ###
We implement the West Cluster as ECK.  You can create a K8s cluster in a laptop environment via [KIND](https://kind.sigs.k8s.io/) and [cloud-provider-kind](https://github.com/kubernetes-sigs/cloud-provider-kind).  


### East Cluster ###
We implement the second cluster (East) in Docker.  Similar to the West Cluster, this is a single Elasticsearch node and Kibana instance.  

![architecture](https://docs.google.com/drawings/d/e/2PACX-1vTI0pMreEb2HVXxjg-uwheciHLMwyZchudpT_aLAI_blDq4snpM6oCU2AfncAWUgNVLKaWmkhTaiAFd/pub?w=1055&h=722) 


## Cross-Cluster Replication Configuration ##
With both clusters operational, the next step involves setting up CCR.  This allows for increased index availability and local read access to improve application performance within a given region. 

### Remote Cluster Configuration ###
We first configure the West cluster to be a remote cluster on the East via the REST API.

```bash
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
```

### Result in Kibana Stack Management ###
![screenshot](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEj4rsvnl9S0jfRqZ6wcyrC5KtD3Q-fm_1FbwbzIGEKuPCX9kzf_dZx2h6-C1BSfHriiR-r9ODbuY7XphfILn3ePgB9sUbT2lG64mqztPKkyCIXPRj3kl8L06SIzuQKt2jtia1WE5zk5nlN8ms1tKSh8hRygiQF4iXB7BlSeYEROuj4I3IVOTvk5KhcmcDE/s16000/xc-east-remote.png)

### Follower Index Creation ###
Next, we create a 'follower' index (`east_ccr`) for the remote cluster's 'leader' index (`west_ccr`). This configuration enables unidirectional replication from the West to the East Cluster, ensuring that data ingested into the leader index is seamlessly replicated to the follower index.

```bash
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
```

### Result in Kibana Stack Management ###
![screenshot](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEhhQLqlbThn90r-1LkTOSC3DcrUOeW2f_Ui-JKzjnkHwiS27lFaiAORpcAmcRqm8xIo7ROII_P-kRRn34xVjtV4fyxmfEPPXOFKkWNrA2w67hzKm1iPDPKJ7HLRjsF0GjnWZQWeBld45iRMDoSD9H6j26ltv9PgqY32SK3Zxtai3UbkfxXFVbk_lEQm5U4/s16000/xc-east-ccr.png)

### Resulting Architecture  ###
![architecture](https://docs.google.com/drawings/d/e/2PACX-1vRRbTGPMFWjADIM7V5T1wnlxBX_CCItwbnbkcCa7QgyQk6JQQlT6_NUu0t-AbcAPaXGZodQlDCIxS82/pub?w=938&h=405)

### Javascript Demo + Output ###
Below is a simple Nodejs client application that returns a sorted list of the docs in the East (`east_ccr`) and West (`west_ccr`) indices.  They're identical, as expected.
```javascript
import { Client } from '@elastic/elasticsearch';
import fs from 'node:fs';

const WEST_IP = '172.18.0.4'; 
const EAST_IP = '192.168.20.2';

const eastClient = new Client({ 
    node: `https://${EAST_IP}:9200`,
    auth: {
        username: 'elastic',
        password: 'elastic'
    },
    tls: {
        ca: fs.readFileSync('../../east/east-ca.crt'),
    }
});

const westClient = new Client({ 
    node: `https://${WEST_IP}:9200`,
    auth: {
        username: 'elastic',
        password: 'elastic'
    },
    tls: {
        ca: fs.readFileSync('../../west/west-http-ca.crt'),
    }
});
let resp = await westClient.search({
    index: 'west_ccr',
    sort: 'release_date:asc',
});
console.log('*** West CCR ***');
for (const hit of resp.hits.hits) {
    console.log(hit._source);
}

resp = await eastClient.search({
    index: 'east_ccr',
    sort: 'release_date:asc',
});
console.log('\n*** East CCR ***');
for (const hit of resp.hits.hits) {
    console.log(hit._source);
}
```
```bash
$ node ccr_test.js
*** West CCR ***
{
  name: 'Snow Crash',
  author: 'Neal Stephenson',
  release_date: '1992-06-01',
  page_count: 470
}
{
  name: 'Revelation Space',
  author: 'Alastair Reynolds',
  release_date: '2000-03-15',
  page_count: 585
}

*** East CCR ***
{
  name: 'Snow Crash',
  author: 'Neal Stephenson',
  release_date: '1992-06-01',
  page_count: 470
}
{
  name: 'Revelation Space',
  author: 'Alastair Reynolds',
  release_date: '2000-03-15',
  page_count: 585
}
```


## Cross-Cluster Search Configuration ##

Elasticsearch's CCS functionality allows users to execute queries across multiple clusters, providing a unified search experience. To implement CCS, the East Cluster is added as a remote cluster to the West Cluster, mirroring the earlier configuration steps. This bidirectional remote cluster setup ensures that both clusters can reference each other during search operations.

### Remote Cluster Configuration ###
```bash
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

curl -s -k -u "elastic:elastic" -X PUT "https://$WEST_ELASTIC_IP:9200/_cluster/settings" \
  -H "Content-Type: application/json" \
  -d "$json"
```
### Result in Kibana Stack Management ###
![screenshot](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEiIFVd6SnI8ooRdd2mfV9etIH1um95_cgE1flUgAJILN2HztmQYMzeXU7GlqtubPARQeZCW-o8eoOLbHTKpgjHAsMdjnqqyMHt1szA7QMYURr6FyFPgZFTGWwfDeM6PPWWBVpur4ZJZR74Y3OcdUWf-pOuI9H9t1FOmYjDQnoYqvox2D3cifrNl7SjiuUI/s16000/xc-westremote.png)

### Resulting Architecture  ###
![architecture](https://docs.google.com/drawings/d/e/2PACX-1vRD_wSSzkUyKycgtpkcluGOsFr8bGTgxV4SPwqMYOazihtLntL_3RwNF7dMvtRT89-63Jvpu1AiNXFY/pub?w=938&h=405)

### Python Demo + Output ###
With the remote cluster configurations in place, indices on both clusters can be queried simultaneously. For instance, a search query executed on the West Cluster can retrieve data from both the `west_ccs` index on the West Cluster and the `east_ccs` index on the East Cluster. This distributed search capability enhances data accessibility and provides users with comprehensive search results spanning multiple data sources.  The python app below searches both indices for documents with a `release_date` greater than or equal to 1985.

east_ccs index contents
```text
{ "index" : { "_index" : "east_ccs" } }
{"name": "Brave New World", "author": "Aldous Huxley", "release_date": "1932-06-01", "page_count": 268}
{ "index" : { "_index" : "east_ccs" } }
{"name": "The Handmaid'"'"'s Tale", "author": "Margaret Atwood", "release_date": "1985-06-01", "page_count": 311}
```

west_ccs index contents
```text
{ "index" : { "_index" : "west_ccs" } }
{"name": "1984", "author": "George Orwell", "release_date": "1985-06-01", "page_count": 328}
{ "index" : { "_index" : "west_ccs" } }
{"name": "Fahrenheit 451", "author": "Ray Bradbury", "release_date": "1953-10-15", "page_count": 227}
```

python script
```python
from elasticsearch import Elasticsearch

WEST_IP = "172.18.0.4" 

client = Elasticsearch(f"https://{WEST_IP}:9200", ca_certs="../../west/west-http-ca.crt", basic_auth=("elastic", "elastic"))
resp = client.search(index=["west_ccs", "east_remote:east_ccs"], query={"range": {"release_date": {"gte": 1985}}})
for hit in resp["hits"]["hits"]:
    print(hit["_source"])
```

output
```bash
$ python3 ccs_test.py
{'name': "The Handmaid's Tale", 'author': 'Margaret Atwood', 'release_date': '1985-06-01', 'page_count': 311}
{'name': '1984', 'author': 'George Orwell', 'release_date': '1985-06-01', 'page_count': 328}
```

## Conclusion ##
Elasticsearch's cross-cluster operations, encompassing both replication and search, offer scalable and resilient solutions for managing data across distributed environments. You can create architectures that yield both geographic redundancy and reduced-latency search operations per region.  Full source [here](https://github.com/joeywhelan/elastic-crosscluster)