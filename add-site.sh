#!/bin/bash
set -e

# =================================================================
# 脚本: add-site.sh
# 功能: 以零停机方式为 OpenResty WAF 添加一个新网站。
#       自动处理 Nginx 配置生成、Let's Encrypt 证书申请与安装。
# 用法: ./add-site.sh <域名> <后端服务地址>
# 示例: ./add-site.sh example.com 172.28.0.20:8080
# =================================================================

# --- 变量定义 ---
DOMAIN=$1
UPSTREAM=$2
TEMPLATE_FILE="template.conf"

# --- 路径定义 ---
BASE_PATH=$(pwd)
CONF_DIR="$BASE_PATH/openresty/conf.d"
SSL_DIR="$BASE_PATH/openresty/ssl"
ACME_DATA_PATH="$BASE_PATH/acme.sh"
WEBROOT_PATH="$BASE_PATH/certbot/www"
DOMAIN_CONF_FILE="$CONF_DIR/$DOMAIN.conf"
DOMAIN_SSL_DIR="$SSL_DIR/$DOMAIN"

# --- 函数: 打印错误信息并退出 ---
error_exit() {
    echo "错误: $1" >&2
    exit 1
}

# --- 函数: 检查 OpenResty 容器状态 ---
check_openresty_running() {
    if [ -z "$(docker-compose ps -q openresty)" ] || [ "$(docker-compose ps -q openresty | xargs docker inspect -f '{{.State.Status}}')" != "running" ]; then
        error_exit "OpenResty 服务未在运行。请先执行 'docker-compose up -d'。"
    fi
}

# --- 函数: 重载 OpenResty 配置 ---
reload_openresty() {
    echo "正在重载 OpenResty 配置..."
    docker-compose exec openresty nginx -s reload
    echo "OpenResty 配置已成功重载。"
}

# --- 步骤 1: 参数校验 ---
echo "步骤 1/6: 正在校验参数..."
if [ -z "$DOMAIN" ] || [ -z "$UPSTREAM" ]; then
    error_exit "请提供域名和后端服务地址。用法: $0 <域名> <后端服务地址>"
fi
if [ ! -f "$TEMPLATE_FILE" ]; then
    error_exit "Nginx 配置模板 '$TEMPLATE_FILE' 未找到。"
fi
if [ -f "$DOMAIN_CONF_FILE" ]; then
    error_exit "域名 '$DOMAIN' 的配置文件已存在，请勿重复添加。"
fi
check_openresty_running
echo "参数校验通过。"

# --- 步骤 2: 创建所需目录 ---
echo "步骤 2/6: 正在创建证书目录..."
mkdir -p "$DOMAIN_SSL_DIR"
mkdir -p "$WEBROOT_PATH" # 确保 ACME webroot 目录存在
echo "目录 '$DOMAIN_SSL_DIR' 已创建。"

# --- 步骤 3: 生成并加载临时配置以进行 ACME 验证 ---
echo "步骤 3/6: 正在生成临时配置以进行 ACME 验证..."
# 只生成用于 ACME 验证的 server 块
awk 'BEGIN{p=0} /server *{/{p=1} p{print} /}/{if(p)exit}' "$TEMPLATE_FILE" | sed "s/__DOMAIN__/$DOMAIN/g" > "$DOMAIN_CONF_FILE"
reload_openresty

# --- 步骤 4: 申请 SSL 证书 ---
echo "步骤 4/6: 正在为 '$DOMAIN' 申请 SSL 证书..."
docker run --rm -it \
  -v "$ACME_DATA_PATH":/acme.sh \
  -v "$WEBROOT_PATH":/webroot \
  neilpang/acme.sh --issue --webroot /webroot -d "$DOMAIN" --server letsencrypt || error_exit "证书申请失败。"

# --- 步骤 5: 安装证书 ---
echo "步骤 5/6: 正在安装证书..."
docker run --rm -it \
  -v "$ACME_DATA_PATH":/acme.sh \
  -v "$DOMAIN_SSL_DIR":/certs \
  neilpang/acme.sh --install-cert -d "$DOMAIN" \
  --cert-file      /certs/fullchain.pem \
  --key-file       /certs/privkey.pem || error_exit "证书安装失败。"
chmod 644 "$DOMAIN_SSL_DIR"/*

# --- 步骤 6: 生成并加载最终配置 ---
echo "步骤 6/6: 正在生成最终的 Nginx 配置..."
sed "s/__DOMAIN__/$DOMAIN/g; s|__UPSTREAM__|$UPSTREAM|g" "$TEMPLATE_FILE" > "$DOMAIN_CONF_FILE"
reload_openresty

# --- 完成 ---
echo "================================================================="
echo "🎉 恭喜！网站 '$DOMAIN' 已成功接入！"
echo " "
echo "   - Nginx 配置文件: $DOMAIN_CONF_FILE"
echo "   - SSL 证书目录: $DOMAIN_SSL_DIR"
echo "   - 后端服务地址: $UPSTREAM"
echo " "
echo "   未来的证书续期将通过 './renew-all-certs.sh' 自动进行。"
echo "================================================================="