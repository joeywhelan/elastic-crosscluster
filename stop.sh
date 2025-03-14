#/bin/bash
cd west
./stop.sh
rm west-ca.crt
rm west-http-ca.crt
cd - > /dev/null
cd east
./stop.sh
rm east-ca.crt