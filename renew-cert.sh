#!/bin/bash
set -e

# 证书续期脚本

# 检查是否提供了域名参数
if [ -z "$1" ]; then
  echo "错误: 请提供您的域名作为第一个参数。"
  echo "用法: $0 your-cn-domain.com"
  exit 1
fi

DOMAIN=$1
ACME_DATA_PATH="$(pwd)/acme.sh"
WEBROOT_PATH="$(pwd)/certbot/www"


# 检查 docker-compose.yml 是否存在
if [ ! -f "docker-compose.yml" ]; then
  echo "错误: 'docker-compose.yml' 未找到。"
  echo "请确保您在 'domestic-vps' 目录下运行此脚本。"
  exit 1
fi

# 确保 acme.sh 数据目录存在
if [ ! -d "$ACME_DATA_PATH" ]; then
    echo "错误: acme.sh 数据目录 '$ACME_DATA_PATH' 不存在。"
    echo "请先至少成功运行一次 'issue-cert.sh' 来申请证书。"
    exit 1
fi

echo "================================================================="
echo "正在为 '$DOMAIN' 续期证书..."
echo "================================================================="

docker run --rm \
  -v "$ACME_DATA_PATH":/acme.sh \
  -v "$WEBROOT_PATH":/webroot \
  neilpang/acme.sh --renew -d "$DOMAIN" --server letsencrypt

echo "================================================================="
echo "证书续期成功! 正在重新加载 OpenResty 服务..."
echo "================================================================="

# 检查 OpenResty 容器是否正在运行
if [ -z "$(docker-compose ps --filter 'status=running' -q openresty)" ]; then
    echo "警告: OpenResty 服务未在运行。如果您已经启动了服务，它将在启动时加载新证书。"
else
    docker-compose exec openresty openresty -s reload
    echo "OpenResty 已成功加载新证书。"
fi

echo "================================================================="
echo "证书续期和重载流程完成！"
echo "================================================================="