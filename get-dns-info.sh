#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <path/to/api_token>"
    exit 1
fi

# Read the API token from the file
CF_API_TOKEN=$(cat "$1")

# Fetch the zone information and extract the zone ID and zone name using jq
ZONE_INFO=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
-H "Authorization: Bearer $CF_API_TOKEN" \
-H "Content-Type: application/json")

# Extract Zone ID and Zone Name
ZONE_ID=$(echo $ZONE_INFO | jq -r '.result[0].id')
ZONE_NAME=$(echo $ZONE_INFO | jq -r '.result[0].name')

# Check if ZONE_ID or ZONE_NAME is empty
if [ -z "$ZONE_ID" ] || [ -z "$ZONE_NAME" ]; then
  echo "Failed to retrieve zone information"
  exit 1
fi

echo "Zone Name: $ZONE_NAME"
echo "Zone ID:   $ZONE_ID"

# Get the DNS records for the given zone
RECORDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
-H "Authorization: Bearer $CF_API_TOKEN" \
-H "Content-Type: application/json")

# Check if records were retrieved
if [ "$(echo $RECORDS | jq -r '.success')" != "true" ]; then
  echo "Failed to retrieve DNS records"
  exit 1
fi

# Extract and list record IDs, names, and types in a table
echo
{
  echo -e "RECORD NAME\tTYPE\tID"
  echo $RECORDS | jq -r '.result[] | "\(.name)\t\(.type)\t\(.id)"'
} | column -t -s $'\t'
