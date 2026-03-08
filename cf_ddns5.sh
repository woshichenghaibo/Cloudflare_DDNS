#!/bin/sh
# --- 配置区 ---
CONFIG_FILE="/root/CF-DDNS.txt"
IP_CHECK_V4="https://4.ident.me"
IP_CHECK_V6="https://6.ident.me"
# --- 初始化与依赖检查 ---
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"
if ! command -v jq > /dev/null; then
    echo "Error: jq is not installed. Run 'opkg update && opkg install jq' first."
    exit 1
fi
# --- 交互式输入 (仅在终端且配置缺失时) ---
if [ -t 0 ] && [ -z "$CF_API_TOKEN" ]; then
    printf "Cloudflare API Token: "; read CF_API_TOKEN
    printf "Zone Name (e.g. domain.com): "; read DNS_NAME
    # 提示用户可以输入多个域名
    printf "Record Names (e.g. abc.domain.com,def.domain.com): "; read DNS_RECORD
    printf "Record Type (A or AAAA): "; read RECORD_TYPE
    cat <<EOF > "$CONFIG_FILE"
CF_API_TOKEN="$CF_API_TOKEN"
DNS_NAME="$DNS_NAME"
DNS_RECORD="$DNS_RECORD"
RECORD_TYPE="$RECORD_TYPE"
EOF
    echo "Configuration saved to $CONFIG_FILE"
fi
# --- 逻辑处理 ---
# 1. 获取当前系统 IP
if [ "$RECORD_TYPE" = "AAAA" ]; then
    CURRENT_IP=$(curl -s -6 --connect-timeout 10 $IP_CHECK_V6)
else
    CURRENT_IP=$(curl -s -4 --connect-timeout 10 $IP_CHECK_V4)
fi
[ -z "$CURRENT_IP" ] && { echo "Error: Could not get current IP."; exit 1; }
# 2. 获取 Zone ID
HDR_AUTH="Authorization: Bearer $CF_API_TOKEN"
HDR_CONT="Content-Type: application/json"
if [ -z "$CACHE_ZONE_ID" ]; then
    CACHE_ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DNS_NAME" \
        -H "$HDR_AUTH" -H "$HDR_CONT" | jq -r '.result[0].id')
    [ "$CACHE_ZONE_ID" != "null" ] && echo "CACHE_ZONE_ID=\"$CACHE_ZONE_ID\"" >> "$CONFIG_FILE"
fi
# 3. 核心：遍历 DNS_RECORD 中的多个域名
RECORDS=$(echo "$DNS_RECORD" | tr ',' ' ')
for RECORD in $RECORDS; do
    echo "Processing $RECORD..."
    
    # 获取该域名的完整数据：包括 Record ID、当前 IP 和 代理状态 (proxied)
    RECORD_DATA=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CACHE_ZONE_ID/dns_records?name=$RECORD&type=$RECORD_TYPE" \
        -H "$HDR_AUTH" -H "$HDR_CONT")
    
    RECORD_ID=$(echo "$RECORD_DATA" | jq -r '.result[0].id')
    OLD_IP=$(echo "$RECORD_DATA" | jq -r '.result[0].content')
    # 【新增】获取该域名当前的代理状态（true 或 false）
    CURRENT_PROXIED=$(echo "$RECORD_DATA" | jq -r '.result[0].proxied')

    if [ "$RECORD_ID" = "null" ] || [ -z "$RECORD_ID" ]; then
        echo "  Error: Record $RECORD not found on Cloudflare. Skipping..."
        continue
    fi

    # 4. 执行更新
    if [ "$CURRENT_IP" != "$OLD_IP" ]; then
        echo "  IP changed: $OLD_IP -> $CURRENT_IP. Updating..."
        
        # 【修改】将 "proxied":true 替换为变量 "$CURRENT_PROXIED"
        # 注意：这里不需要引号，因为 jq 读出来的是布尔值常量
        DATA="{\"type\":\"$RECORD_TYPE\",\"name\":\"$RECORD\",\"content\":\"$CURRENT_IP\",\"ttl\":1,\"proxied\":$CURRENT_PROXIED}"
        
        RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CACHE_ZONE_ID/dns_records/$RECORD_ID" \
                    -H "$HDR_AUTH" -H "$HDR_CONT" --data "$DATA")
        
        if [ "$(echo "$RESPONSE" | jq -r '.success')" = "true" ]; then
            echo "  $RECORD update successful (Proxied: $CURRENT_PROXIED)."
        else
            echo "  $RECORD update failed: $(echo "$RESPONSE" | jq -c '.errors')"
        fi
    else
        echo "  $RECORD IP is up to date ($CURRENT_IP). Proxied state remains $CURRENT_PROXIED."
    fi
done
echo "DDNS Check Done."
