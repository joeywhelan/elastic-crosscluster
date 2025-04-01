# Elastic Cross-Cluster Operations
## Contents
1.  [Summary](#summary)
2.  [Architecture](#architecture)
3.  [Features](#features)
4.  [Prerequisites](#prerequisites)
5.  [Installation](#installation)
6.  [Usage](#usage)

## Summary <a name="summary"></a>
This is a K8s + Docker demonstration of cross-cluster functionality available in Elasticsearch (ES).

## Architecture <a name="architecture"></a>
![architecture](https://docs.google.com/drawings/d/e/2PACX-1vTI0pMreEb2HVXxjg-uwheciHLMwyZchudpT_aLAI_blDq4snpM6oCU2AfncAWUgNVLKaWmkhTaiAFd/pub?w=1055&h=722)  

## Features <a name="features"></a>
- Builds a single ES node + Kibana cluster in K8s.
- Builds a second single ES node + Kibana cluster in Docker.
- Configures both clusters as remote clusters to each other.
- Sets up a cross-cluster replication (CCR) scenario and demonstrates the data replication via a Nodejs client.
- Sets up a cross-cluster search (CCS) scenario and demonstrates the search across both clusters via a Python client.


## Prerequisites <a name="prerequisites"></a>
- Docker
- Docker Compose
- go
- Kind
- helm
- kubectl
- jq
- python3
- nodejs

## Installation <a name="installation"></a>
```bash
git clone git@github.com:joeywhelan/elastic-crosscluster.git && cd elastic-crosscluster
```

## Usage <a name="usage"></a>
### K8s + Docker ES Clusters Start-up
```bash
./start.sh
```
### Nodejs CCR Demo
- Update the WEST_IP var to the IP address assigned to the westcluster-es-http service
```bash
cd src/javascript
npm install
node ccr_test.js
```
### Python CCS Demo
- Update the WEST_IP var to the IP address assigned to the westcluster-es-http service
```bash
cd src/python
pip install elasticsearch
python3 ccs_test.py
```
### K8s + Docker ES Clusters Shutdown
```bash
./stop.sh
```