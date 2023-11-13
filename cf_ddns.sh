#!/bin/bash

EMAIL="<YOUR_EMAIL>"
API_KEY="<YOUR_API_KEY>"
ZONE_ID="<YOUR_ZONE_ID>"
DOMAIN="<YOUR_DOMAIN>"

IP=\$(curl -s https://api.ipify.org)

curl -X PUT "https://api.cloudflare.com/client/v4/zones/\$ZONE_ID/dns_records/\$DOMAIN" \
     -H "Authorization: Bearer \$API_KEY" \
     -H "Content-Type: application/json" \
     --data "{\"type\":\"A\",\"name\":\"\$DOMAIN\",\"content\":\"\$IP\",\"ttl\":120,\"proxied\":false}"
