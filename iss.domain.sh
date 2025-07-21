#!/bin/bash
set -e

# 检查是否提供了域名参数
if [ -z "$1" ]; then
  echo "错误: 请提供您的域名作为第一个参数。"
  echo "用法: $0 your-cn-domain.com"
  exit 1
fi

DOMAIN=$1
SSL_PATH="$(pwd)/openresty/ssl"
ACME_DATA_PATH="$(pwd)/acme.sh"
WEBROOT_PATH="$(pwd)/certbot/www"

# 检查 docker-compose.yml 是否存在
if [ ! -f "docker-compose.yml" ]; then
  echo "错误: 'docker-compose.yml' 未找到。"
  echo "请确保您在目录下运行此脚本。"
  exit 1
fi

# 确保相关目录存在
mkdir -p "$SSL_PATH"
mkdir -p "$ACME_DATA_PATH"
mkdir -p "$WEBROOT_PATH"

# 步骤1: 停止现有服务，释放80端口
if [ "$(docker-compose ps -q)" ]; then
    echo "检测到服务正在运行，正在停止服务以释放80端口..."
    docker-compose down --remove-orphans
    echo "服务已停止。"
fi

# 步骤2: 使用 standalone 模式首次申请证书
echo "================================================================="
echo "步骤1/3: 正在使用 Standalone 模式为 '$DOMAIN' 申请证书..."
echo "================================================================="
docker run --rm -it \
  -v "$ACME_DATA_PATH":/acme.sh \
  -p 80:80 \
  neilpang/acme.sh --issue --standalone -d "$DOMAIN" --server letsencrypt

# 步骤3: 安装证书
echo "================================================================="
echo "步骤2/3: 正在安装证书到 $SSL_PATH ..."
echo "================================================================="
docker run --rm -it \
  -v "$ACME_DATA_PATH":/acme.sh \
  -v "$SSL_PATH":/certs \
  neilpang/acme.sh --install-cert -d "$DOMAIN" \
  --cert-file      /certs/fullchain.pem \
  --key-file       /certs/privkey.pem

# 步骤4: 将续期模式更新为 webroot，为自动续期做准备
echo "================================================================="
echo "步骤3/3: 正在将续期模式更新为 Webroot ..."
echo "================================================================="
docker run --rm -it \
  -v "$ACME_DATA_PATH":/acme.sh \
  -v "$WEBROOT_PATH":/webroot \
  neilpang/acme.sh --issue --webroot /webroot -d "$DOMAIN" --server letsencrypt

# 赋予证书正确的权限
chmod 644 "$SSL_PATH"/*

echo "================================================================="
echo "证书申请和配置全部完成！"
echo " "
echo "现在，请执行 'docker-compose up -d' 来启动所有服务。"
echo "未来的证书续期将自动通过 Webroot 方式进行。"
echo "=================================================================" 
