#!/bin/bash
set -e

# 此脚本用于为Nginx/OpenResty的默认服务器块生成一个自签名SSL证书。
# 这个证书用于捕获所有未匹配到server_name的HTTPS请求并返回404，
# 从而防止IP直连和恶意域名绑定。

SSL_PATH="$(pwd)/openresty/ssl/default"
# 确保输出目录存在
mkdir -p "$SSL_PATH"

# 定义证书和密钥路径
CERT_FILE="$SSL_PATH/snakeoil.pem"
KEY_FILE="$SSL_PATH/snakeoil.key"


# 检查证书是否已存在
if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
    echo "自签名证书和密钥已存在，跳过生成。"
else
    echo "生成自签名证书和密钥..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$KEY_FILE" -out "$CERT_FILE" \
        -subj "/C=US/ST=Denial/L=Nowhere/O=Net/CN=localhost"
    echo "自签名证书和密钥已生成。"
