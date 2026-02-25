#!/bin/sh

# --- 配置区 ---
CONFIG_FILE="/root/CF-DDNS.txt"
IP_CHECK_V4="https://4.ident.me"
IP_CHECK_V6="https://6.ident.me"

# --- 初始化与依赖检查 ---
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

# OpenWrt 通常预装了 jq，如果没有，请执行 opkg update && opkg install jq
if ! command -v jq > /dev/null; then
    echo "Error: jq is not installed. Run 'opkg update && opkg install jq' first."
    exit 1
fi

# --- 交互式输入 (仅在终端且配置缺失时) ---
if [ -t 0 ] && [ -z "$CF_API_TOKEN" ]; then
    printf "Cloudflare API Token: "; read CF_API_TOKEN
    printf "Zone Name (e.g. example.com): "; read DNS_NAME
    printf "Record Name (e.g. ddns.example.com): "; read DNS_RECORD
    printf "Record Type (A or AAAA): "; read RECORD_TYPE
    
    cat <<EOF > "$CONFIG_FILE"
CF_API_TOKEN="$CF_API_TOKEN"
DNS_NAME="$DNS_NAME"
DNS_RECORD="$DNS_RECORD"
RECORD_TYPE="$RECORD_TYPE"
EOF
fi

# --- 逻辑处理 ---

# 1. 获取当前系统 IP
if [ "$RECORD_TYPE" = "AAAA" ]; then
    CURRENT_IP=$(curl -s -6 --connect-timeout 10 $IP_CHECK_V6)
else
    CURRENT_IP=$(curl -s -4 --connect-timeout 10 $IP_CHECK_V4)
fi

[ -z "$CURRENT_IP" ] && { echo "Error: Could not get current IP."; exit 1; }

# 2. 获取并缓存 ID (Ash 不支持数组，改用变量)
HDR_AUTH="Authorization: Bearer $CF_API_TOKEN"
HDR_CONT="Content-Type: application/json"

if [ -z "$CACHE_ZONE_ID" ]; then
    CACHE_ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DNS_NAME" \
        -H "$HDR_AUTH" -H "$HDR_CONT" | jq -r '.result[0].id')
    [ "$CACHE_ZONE_ID" != "null" ] && echo "CACHE_ZONE_ID=\"$CACHE_ZONE_ID\"" >> "$CONFIG_FILE"
fi

if [ -z "$CACHE_RECORD_ID" ]; then
    CACHE_RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CACHE_ZONE_ID/dns_records?name=$DNS_RECORD&type=$RECORD_TYPE" \
        -H "$HDR_AUTH" -H "$HDR_CONT" | jq -r '.result[0].id')
    [ "$CACHE_RECORD_ID" != "null" ] && echo "CACHE_RECORD_ID=\"$CACHE_RECORD_ID\"" >> "$CONFIG_FILE"
fi

# 3. 检查 Cloudflare 上的旧 IP
OLD_IP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CACHE_ZONE_ID/dns_records/$CACHE_RECORD_ID" \
    -H "$HDR_AUTH" -H "$HDR_CONT" | jq -r '.result.content')

# 4. 执行更新
if [ "$CURRENT_IP" != "$OLD_IP" ]; then
    echo "IP changed: $OLD_IP -> $CURRENT_IP. Updating..."
    
    # 构造 JSON
    DATA="{\"type\":\"$RECORD_TYPE\",\"name\":\"$DNS_RECORD\",\"content\":\"$CURRENT_IP\",\"ttl\":1,\"proxied\":true}"
           
    RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CACHE_ZONE_ID/dns_records/$CACHE_RECORD_ID" \
               -H "$HDR_AUTH" -H "$HDR_CONT" --data "$DATA")
               
    if [ "$(echo "$RESPONSE" | jq -r '.success')" = "true" ]; then
        echo "Update successful."
    else
        echo "Update failed: $RESPONSE"
    fi
else
    echo "IP not changed ($CURRENT_IP)."
fi