import { Client } from '@elastic/elasticsearch';
import fs from 'node:fs';

const WEST_IP = '172.18.0.5'; //change this to match the external IP assigned to westcluster-es-http
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