# cf_ddns简介
该脚本用于自动更新 Cloudflare DNS 记录的 IP 地址。它适用于需要定期更新 DNS 记录以匹配动态 IP 地址的情况

## 食用教程：
### 一、下载脚本
```shell
wget https://raw.githubusercontent.com/jinqians/cd_ddns/main/cf_ddns.sh
```
### 二、获取API密钥
打开cloudflare，在My Profile--->API Tokens中获取Global API密钥

### 三、配置脚本信息
在首次运行脚本时，它会提示你输入 Cloudflare 账户信息和其他配置，包括：<br>
+ Cloudflare 账户的邮箱（Auth Email） <br>
+ Cloudflare 账户的 API Key（Auth Key） <br>
+ Cloudflare 区域名称（Zone Name） <br>
+ 需要更新的 DNS 记录名称（Record Name） <br>

以上信息填写完成后，选择要更新的 IP 类型（IPv4 或 IPv6）。

### 四、设置定时任务
使用`crontab -e`添加定时任务，例如5分钟执行一次

```shell
*/5 * * * * /bin/bash/ <空格> /your path/cf_ddns.sh
```
## 其他相关说明
### 后续运行：
在第一次配置完成后，脚本会将这些配置保存到 * cloudflare_config.txt * 文件中。后续运行时，脚本将直接从配置文件中读取这些配置，无需再次输入。

### 日志和错误处理：
脚本会将执行日志记录到 cloudflare.log 文件中。如果发生任何错误，它也会将错误信息输出到日志文件中，以便你进行排查。

