# A test script 

#!/bin/bash

MAIN_URL="http://localhost:8080/users"

echo "Creating 3 users..."

curl -X POST $MAIN_URL -H "Content-Type: application/json" -d '{"name":"Alice"}'
echo
curl -X POST $MAIN_URL -H "Content-Type: application/json" -d '{"name":"Bob"}'
echo
curl -X POST $MAIN_URL -H "Content-Type: application/json" -d '{"name":"Charlie"}'
echo

echo "Fetching all users:"
curl -X GET $MAIN_URL
echo
Creating 3 users...
