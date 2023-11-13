# cf_ddns
cloudflare 动态 DNS（DDNS）！Cloudflare 的 DDNS 功能允许您通过 API 更新您的域名解析记录，使之适用于动态 IP 地址。

## 食用说明
### 第一步，下载脚本
`wget https://raw.githubusercontent.com/jinqians/cd_ddns/main/cf_ddns.sh`
### 第二步，获取API密钥
获取API密钥，并更改脚本以下内容
用您的信息替换 <YOUR_EMAIL>、<YOUR_API_KEY>、<YOUR_ZONE_ID> 和 <YOUR_DOMAIN>
### 第三步，运行脚本
`bash cloudflare_ddns.sh`
### 第四步，设置定时任务
每小时运行一次
`*/1 * * * * /bin/bash /path/to/cloudflare_ddns.sh`
