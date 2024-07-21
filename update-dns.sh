#!/bin/bash

# 
# There is one flag: --silent (or -s)
# When it is toggled, the only output this produces is error messages!
#

cd /home/saeculum/update-dns-records/

# File paths
active_records=active-records.json
default_request=default-request.json

current_date=$(date +"%Y-%m-%d %H:%M:%S")
current_ip=$(curl ifconfig.me -4 -s)

# Set payload for all requests
default_payload=$(jq --arg current_ip "$current_ip" --arg current_date "$current_date" '
  .payload |
  .content |= gsub("CURRENT_IP_PLACEHOLDER"; $current_ip) |
  .comment |= gsub("CURRENT_DATE_PLACEHOLDER"; $current_date)
' $default_request)

# Headers are set down at the request because I didn't want to figure out how to
# send json headers



# Iterate over each zone
zones=$(jq -r '.zones | keys[]' $active_records)
for zone in $zones; do
  # Get API token
  api_token=$(cat api-tokens/$zone)

  # Extract name from local json
  zone_name=$(jq -r ".zones[\"$zone\"].name" $active_records)

  # Fetch the zone information from Cloudflare
  cf_zone_data=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
      -H "Authorization: Bearer $api_token" \
      -H "Content-Type: application/json")

  # Get the zone ID for the record whose name matches the one in the json file
  # WARNING: If multiple zones have the same name, this will only return the
  # first!
  zone_id=$(echo $cf_zone_data | jq -r --arg zone_name "$zone_name" ' .result[] | select(.name == $zone_name) | .id' | head -n 1)
  #echo -e "Updating DNS for zone: $zone_name\n"

  # Fetch record info for the current zone
  cf_record_data=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
      -H "Authorization: Bearer $api_token" \
      -H "Content-Type: application/json")
  
  # Grabs the record ids
  records=$(jq -c ".zones[\"$zone\"].records[]" $active_records)
  for record in $records; do
    filtered_data=$cf_record_data

    for key in $(echo $record | jq -r 'keys[]'); do
      if [ -z "$filtered_data" ]; then
        echo "Found no Cloudflare records matching $(echo $record | jq -r .name)"
        break
      fi
      value=$(echo $record | jq -r --arg key "$key" '.[$key]')
      filtered_data=$(echo $filtered_data | jq -c --arg key "$key" --arg value "$value" ' .result |= map(select(.[$key] == $value))')
    done

    # Move along
    if [ -z "$filtered_data" ]; then
      continue
    fi

    # Record ID acquired lmao
    record_id=$(echo $filtered_data | jq -r ' .result[0] | .id')

    #echo "Updating DNS for record: $(echo $filtered_data | jq -r ' .result[0] | .name')"

    header=$zone_header
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
      echo "Response $(date +%y-%m-%d_%H-%M-%S): failure!"
      jq . <<< $response
    fi
  done
done
