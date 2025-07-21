# OpenResty WAF 域名接入管理系统

本项目提供了一套自动化的脚本，用于通过 OpenResty WAF 快速、零停机地接入和管理多个网站，并自动处理 Let's Encrypt SSL 证书的申请和续期。

## 架构概览

- **核心服务**: `openresty/openresty` Docker 镜像作为 WAF 和反向代理。
- **配置**: 每个网站的 Nginx 配置和 SSL 证书都存储在以其域名命名的独立目录中，实现了资源的隔离。
- **自动化**: 通过 `add-site.sh` 和 `renew-all-certs.sh` 两个核心脚本实现全流程自动化。

## 先决条件

1.  **Docker 和 Docker Compose**: 确保您的系统已安装这两个工具。
2.  **域名**: 您需要拥有一个域名，并将其 DNS A 记录指向运行此项目的服务器的公共 IP 地址。
3.  **防火墙**: 确保服务器的 80 和 443 端口已开放。

## 首次设置

1.  **创建 Docker 网络**:
    ```bash
    ./net.create
    ```

2.  **生成自签名证书**:
    此证书用于处理未匹配任何已配置域名的 HTTPS 请求，增强安全性。
    ```bash
    ./generate-self-signed-cert.sh
    ```

3.  **启动核心服务**:
    ```bash
    docker-compose up -d
    ```

## 如何使用

### 添加一个新网站

使用 `add-site.sh` 脚本，并提供**域名**和**后端服务地址**作为参数。

**命令格式**:
```bash
./add-site.sh <您的域名> <后端服务地址:端口>
```

**示例**:
假设您要接入域名 `www.example.com`，其后端业务服务运行在 `172.28.0.20` 的 `8080` 端口上。
```bash
./add-site.sh www.example.com 172.28.0.20:8080
```

脚本将自动完成以下所有操作，且**不会中断**任何现有服务：
- 创建 Nginx 配置文件 (`./openresty/conf.d/www.example.com.conf`)
- 申请 Let's Encrypt 证书
- 将证书安装到专属目录 (`./openresty/ssl/www.example.com/`)
- 平滑重载 OpenResty 以应用新配置

### 自动续期 SSL 证书

`renew-all-certs.sh` 脚本会自动检测所有已配置的网站，并为即将过期的证书续期。

您可以将此脚本添加到系统的 `crontab` 中，以实现无人值守的自动续期。

**手动执行**:
```bash
./renew-all-certs.sh
```

**添加到 Cron (示例: 每天凌晨 2:30 自动运行)**:
1.  打开 crontab 编辑器: `crontab -e`
2.  添加以下行 (请将 `/path/to/project` 替换为本项目的绝对路径):
    ```
    30 2 * * * /path/to/project/renew-all-certs.sh >> /path/to/project/cron.log 2>&1
    ```

## 文件和目录结构

- `add-site.sh`: 用于添加新网站的核心脚本。
- `renew-all-certs.sh`: 用于自动续期所有证书的脚本。
- `template.conf`: Nginx 配置模板，`add-site.sh` 会基于此文件生成配置。
- `docker-compose.yml`: 定义了 OpenResty 服务。
- `openresty/conf.d/`: 存放所有网站的 Nginx 配置文件。
- `openresty/ssl/`: 存放所有网站的 SSL 证书。
- `certbot/www/`: 用于 Let's Encrypt ACME 验证的共享目录。
- `acme.sh/`: `acme.sh` 工具的数据目录，存储证书信息。