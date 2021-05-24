#!/bin/bash

# Exit if any of the intermediate steps fail
set -e

eval "$(jq -r '@sh "IP_ADDRESS=\(.ip_address)"')"

TOKEN=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $1 $2@$IP_ADDRESS "awk '/Secret ID/ {print \$4}' bootstrap.token")

# Safely produce a JSON object containing the result value.
# jq will ensure that the value is properly quoted
# and escaped to produce a valid JSON string.
jq -n --arg token "$TOKEN" '{$token}'
