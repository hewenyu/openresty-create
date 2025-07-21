#!/bin/bash
set -e

# =================================================================
# 脚本: renew-all-certs.sh
# 功能: 自动续期所有通过 acme.sh 管理的 Let's Encrypt 证书。
#       此脚本设计为通过 cron 定时任务自动运行。
# 用法: ./renew-all-certs.sh
# =================================================================

# --- 路径定义 ---
BASE_PATH=$(cd "$(dirname "$0")" && pwd)
ACME_DATA_PATH="$BASE_PATH/acme.sh"
WEBROOT_PATH="$BASE_PATH/certbot/www"

# --- 函数: 打印错误信息并退出 ---
error_exit() {
    echo "错误: $1" >&2
    exit 1
}

# --- 函数: 检查 OpenResty 容器状态 ---
is_openresty_running() {
    if [ -n "$(docker-compose -f "$BASE_PATH/docker-compose.yml" ps -q openresty)" ] && [ "$(docker-compose -f "$BASE_PATH/docker-compose.yml" ps -q openresty | xargs docker inspect -f '{{.State.Status}}')" == "running" ]; then
        return 0 # true
    else
        return 1 # false
    fi
}

# --- 步骤 1: 环境检查 ---
echo "步骤 1/3: 正在检查环境..."
if [ ! -d "$ACME_DATA_PATH" ]; then
    echo "信息: acme.sh 数据目录未找到，无需续期。退出。"
    exit 0
fi
if ! is_openresty_running; then
    error_exit "OpenResty 服务未在运行，无法执行基于 webroot 的续期。"
fi
echo "环境检查通过。"

# --- 步骤 2: 执行续期 ---
echo "步骤 2/3: 正在执行 'acme.sh --renew-all'..."
# acme.sh 会自动检查所有证书，只续期即将过期的
docker run --rm \
  -v "$ACME_DATA_PATH":/acme.sh \
  -v "$WEBROOT_PATH":/webroot \
  neilpang/acme.sh --renew-all --server letsencrypt

# --- 步骤 3: 重新加载 OpenResty ---
echo "步骤 3/3: 正在重新加载 OpenResty 以应用新证书..."
# 即使没有证书被续期，重载也是安全的操作
docker-compose -f "$BASE_PATH/docker-compose.yml" exec openresty nginx -s reload

# --- 完成 ---
echo "================================================================="
echo "✅ 证书自动续期流程完成！"
echo "   所有需要续期的证书均已更新，OpenResty 配置已重载。"
echo "================================================================="