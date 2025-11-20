# Cloudflare Update DDNS

Based on https://github.com/K0p1-Git/cloudflare-ddns-updater.

## Functionality

Checks if local IPv4 address or IPv6 prefix did change and update DNS records on cloudflare.

To avoid API calls status is stored in two local files.

Every 'run_minute' of the hour stored files are ignored to ensure correct records in case of update failure.

Also if there is no change, nothing is updated in records.

## Installation

Copy the .sh wherever you like and make it executable.

## Dependencies

* curl
* jq

## Configuration

See the top of the .sh and fill with correct data.

```
auth_email="email@address.com"                        # Cloudflare login email
auth_key="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"   # Zone.DNS.Edit API token
zone_identifier="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"    # Zone identifier
current_ipv4_file="/tmp/current_ipv4"                 # File to store current IPv4
current_ipv6_prefix_file="/tmp/current_ipv6_prefix"   # File to store current IPv6 prefix
run_minute="35"                                       # At which minute to forced run check each hour
```

# Cloudflare DSN Records

All IPv6 addresses in cloudflare records need to be uncompressed (no :: inside address).

## Run Via cron Every Minute

```
> cat /etc/cron.d/cloudflare_update_ddns
* * * * * root /usr/local/bin/cloudflare_update_ddns.sh >/dev/null 2>&1
```
## IPv6 Prefix

The default prefix is /64- If you want to change that you need to alter `REGEX_IPV6`.

### Default /64

```
REGEX_IPV6="([0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}):([0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4})"
                                                                                ^^^
```

### Example /56

```
`REGEX_IPV6="([0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}):([0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4})"`
                                                                ^^^
```
