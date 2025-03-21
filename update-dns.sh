#!/bin/bash

# 
# There is one flag: --silent (or -s)
# When it is toggled, the only output this produces is error messages.
#

cd "$(dirname "${BASH_SOURCE[0]}")"

# File paths
default_request=default-request.json

current_date=$(date +"%Y-%m-%d %H:%M:%S")
current_ip=$(curl ifconfig.me -4 -s)

# Set payload for all requests
default_payload=$(jq --arg current_ip "$current_ip" --arg current_date "$current_date" '
  .payload |
  .content |= gsub("CURRENT_IP_PLACEHOLDER"; $current_ip) |
  .comment |= gsub("CURRENT_DATE_PLACEHOLDER"; $current_date)
' $default_request)

api_token=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
zone_id=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
record_id=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
record="{\"id\":\"$record_id\"}"

payload=$(jq -n --argjson record "$record" --argjson default_payload "$default_payload" '
  $default_payload as $payload |
  $record | to_entries | reduce .[] as $item (
    $payload;
    .[$item.key] = $item.value
  )
')

# Yes, queen.
api_endpoint="https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id"

# Making put request and storing response
response=$(curl -s -X PUT "$api_endpoint" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $api_token" \
    -d "$payload")

if [ $(jq .success <<< $response) = "true" ]; then
  if [ "$1" != "-s" ] && [ "$1" != "--silent" ]; then
    echo "Make PUT request for record id \`$record_id\`"
    echo "Response $(date +%y-%m-%d_%H-%M-%S): success!"
  fi
else
  echo "Make PUT request for record id \`$record_id\`"
  echo "Response $(date +%y-%m-%d_%H-%M-%S): failure."
  jq . <<< $response
fi
