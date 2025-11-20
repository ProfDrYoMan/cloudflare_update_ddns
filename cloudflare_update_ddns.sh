#!/bin/bash
#
# Cloudflare Update DDNS
#  MIT License
#  (C) holger@rusch.name
#
# Run via cron every minute.
#
# > cat /etc/cron.d/cloudflare_update_ddns
# * * * * * root /usr/local/bin/cloudflare_update_ddns.sh >/dev/null 2>&1
#
# IPv6 prefix is /64.
# 
# All IPv6 addresses in the cloudflare record need to be uncompressed (no :: inside address).

# Config
auth_email="email@address.com"                        # Cloudflare login email
auth_key="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"   # Zone.DNS.Edit API token
zone_identifier="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"    # Zone identifier
current_ipv4_file="/tmp/current_ipv4"                 # File to store current IPv4
current_ipv6_prefix_file="/tmp/current_ipv6_prefix"   # File to store current IPv6 prefix
run_minute="35"                                       # At which minute to forced run check each hour

# Don't touch
REGEX_IPV4="([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"
REGEX_IPV6="([0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}):([0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4})"

# IPv4
RAW_IP=$(curl -4 -s https://one.one.one.one/cdn-cgi/trace)
if [[ $RAW_IP =~ ip=$REGEX_IPV4 ]]; then
  CURRENT_IP=${BASH_REMATCH[1]}
else
  logger -s "DDNS Updater: IPv4 detection failed."
  exit 2
fi

# Only if there is change or we are in run_minute
if [[ ( $(date +"%M") == $run_minute ) || ( ! ( -f $current_ipv4_file && ( $CURRENT_IP == $(< $current_ipv4_file) ) ) ) ]]; then
  echo $CURRENT_IP > $current_ipv4_file

# Get A records
  records=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?type=A" \
                        -H "X-Auth-Email: $auth_email" \
                        -H "Authorization: Bearer $auth_key" \
                        -H "Content-Type: application/json")

  record_numbers=$(echo $records | jq .result_info.total_count)

# For all records
  for ((record_number=0;record_number<$record_numbers;record_number++)); do
    record_identifier=$(echo $records | jq -r .result[$record_number].id)
    record_name=$(echo $records | jq -r .result[$record_number].name)
    record_content=$(echo $records | jq -r .result[$record_number].content)

# Continue if no change
    if [[ $CURRENT_IP == $record_content ]]; then
      logger -s "DDNS Updater: IP ($record_content) for ${record_name} has not changed."
      continue
    fi

# Update record
    update=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
                       -H "X-Auth-Email: $auth_email" \
                       -H "Authorization: Bearer $auth_key" \
                       -H "Content-Type: application/json" \
                       --data "{\"name\":\"$record_name\",\"content\":\"$CURRENT_IP\"}")

    if [[ "true" == $(echo $update | jq .success) ]]; then
      logger -s "DDNS Updater: IP ($record_content) => ($CURRENT_IP) for ${record_name} set."
    else
      logger -s "DDNS Updater: IP ($record_content) => ($CURRENT_IP) for ${record_name} could not be set."
    fi
  done
fi

# IPv6
RAW_IP=$(curl -6 -s https://one.one.one.one/cdn-cgi/trace)
if [[ $RAW_IP =~ ip=$REGEX_IPV6 ]]; then
  CURRENT_IP_PREFIX=${BASH_REMATCH[1]}
  CURRENT_IP=${CURRENT_IP_PREFIX}:${BASH_REMATCH[2]}
else
  logger -s "DDNS Updater: IPv6 detection failed."
  exit 2
fi

# Only if there is change or we ar in run_minute
if [[ ( $(date +"%M") == $run_minute ) || ( ! ( -f $current_ipv6_prefix_file && ( $CURRENT_IP_PREFIX == $(< $current_ipv6_prefix_file) ) ) ) ]]; then
  echo $CURRENT_IP_PREFIX > $current_ipv6_prefix_file

# Get AAAA records
  records=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?type=AAAA" \
                        -H "X-Auth-Email: $auth_email" \
                        -H "Authorization: Bearer $auth_key" \
                        -H "Content-Type: application/json")

  record_numbers=$(echo $records | jq .result_info.total_count)

# For all records
  for ((record_number=0;record_number<$record_numbers;record_number++)); do
    record_identifier=$(echo $records | jq -r .result[$record_number].id)
    record_name=$(echo $records | jq -r .result[$record_number].name)
    record_content=$(echo $records | jq -r .result[$record_number].content)

# Should not happen
    if [[ $record_content =~ $REGEX_IPV6 ]]; then
      record_prefix=${BASH_REMATCH[1]}
    else
      logger -s "DDNS Updater: Could not extract prefix."
      continue
    fi

# Continue if no change
    if [[ $CURRENT_IP_PREFIX == $record_prefix ]]; then
      logger -s "DDNS Updater: Prefix ($record_prefix) for ${record_name} has not changed."
      continue
    fi

# Should not happen
    if [[ $record_content =~ $REGEX_IPV6 ]]; then
      record_postfix=${BASH_REMATCH[2]}
      NEW_IP=${CURRENT_IP_PREFIX}:${record_postfix}
    else
      logger -s "DDNS Updater: Could not extract postfix."
      continue
    fi

# Update record
    update=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
                       -H "X-Auth-Email: $auth_email" \
                       -H "Authorization: Bearer $auth_key" \
                       -H "Content-Type: application/json" \
                       --data "{\"name\":\"$record_name\",\"content\":\"$NEW_IP\"}")

    if [[ "true" == $(echo $update | jq .success) ]]; then
      logger -s "DDNS Updater: IP ($record_content) => ($NEW_IP) for ${record_name} set."
    else
      logger -s "DDNS Updater: IP ($record_content) => ($NEW_IP) for ${record_name} could not be set."
    fi
  done
fi
