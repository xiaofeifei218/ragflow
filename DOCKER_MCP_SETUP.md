# Docker内MCP服务器HTTPS配置指南

本文档说明如何配置Docker内运行的MCP服务器，通过宿主机nginx进行HTTPS反向代理。

## 架构说明

```
[MCP Client]
     ↓ HTTPS
[宿主机 Nginx:443] → ddbmcp.xiaofeifei.fun
     ↓ HTTP
[宿主机:9382] ← 端口映射
     ↓
[Docker容器内 MCP:9382]
     ↓ HTTP
[Docker容器内 RAGFlow:9380]
```

## 关键配置修改

### 1. 修改 docker-compose.yml

你需要修改 `docker/docker-compose.yml` 文件中的两个地方：

#### 修改A: MCP监听地址（关键！）

将 `--mcp-host` 从 `127.0.0.1` 改为 `0.0.0.0`：

```yaml
services:
  ragflow-cpu:
    image: ${RAGFLOW_IMAGE}
    command:
      - --enable-mcpserver
      - --mcp-host=0.0.0.0      # ← 改这里！从 127.0.0.1 改为 0.0.0.0
      - --mcp-port=9382
      - --mcp-base-url=http://127.0.0.1:9380
      - --mcp-script-path=/ragflow/mcp/server/server.py
      - --mcp-mode=self-host
      - --mcp-host-api-key=ragflow-kxxxxxxxxx
```

**为什么要修改？**
- `127.0.0.1` = 只监听容器**内部**的localhost，宿主机无法通过端口映射访问
- `0.0.0.0` = 监听容器的所有网络接口，允许外部（宿主机）通过端口映射访问

#### 修改B: 启用端口映射

确保端口映射**没有被注释**：

```yaml
services:
  ragflow-cpu:
    ports:
      - ${SVR_WEB_HTTP_PORT}:80
      - ${SVR_WEB_HTTPS_PORT}:443
      - ${SVR_HTTP_PORT}:9380
      - ${ADMIN_SVR_HTTP_PORT}:9381
      - ${SVR_MCP_PORT}:9382    # ← 确保这行没有 # 注释符号
```

这会将容器的9382端口映射到宿主机的9382端口（由`.env`中的`SVR_MCP_PORT=9382`定义）。

### 2. 验证 .env 配置

确认 `docker/.env` 文件中包含：

```bash
SVR_MCP_PORT=9382
```

这个变量定义了MCP服务器映射到宿主机的端口号。

### 3. 宿主机 Nginx 配置

使用以下nginx配置文件之一（已创建在项目根目录）：

**推荐使用：`nginx_mcp_standalone.conf`**

```nginx
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name ddbmcp.xiaofeifei.fun;
    return 301 https://$host$request_uri;
}

# HTTPS server for MCP
server {
    listen 443 ssl;
    server_name ddbmcp.xiaofeifei.fun;

    ssl_certificate /home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/fullchain.cer;
    ssl_certificate_key /home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/xiaofeifei.fun.key;

    # 反向代理到宿主机的9382端口（Docker端口映射）
    location /sse {
        proxy_pass http://127.0.0.1:9382;
        # ... proxy配置
    }

    location /mcp {
        proxy_pass http://127.0.0.1:9382;
        # ... proxy配置
    }
}
```

注意：nginx反向代理到 `http://127.0.0.1:9382`，这是宿主机的端口，不是Docker容器内的端口。

## 完整部署步骤

### 步骤1: 修改 docker-compose.yml

编辑 `docker/docker-compose.yml`：

```bash
cd /home/user/ragflow/docker

# 备份原文件
cp docker-compose.yml docker-compose.yml.backup

# 编辑文件，修改以下两处：
# 1. --mcp-host=127.0.0.1 → --mcp-host=0.0.0.0
# 2. 取消注释 - ${SVR_MCP_PORT}:9382
vim docker-compose.yml
```

或使用sed自动修改：

```bash
cd /home/user/ragflow/docker

# 修改MCP监听地址
sed -i 's/--mcp-host=127\.0\.0\.1/--mcp-host=0.0.0.0/' docker-compose.yml

# 如果端口映射被注释了，取消注释
sed -i 's/# *- ${SVR_MCP_PORT}:9382/- ${SVR_MCP_PORT}:9382/' docker-compose.yml
```

### 步骤2: 重启 Docker 容器

```bash
cd /home/user/ragflow/docker

# 停止容器
docker compose down

# 启动容器
docker compose up -d

# 查看日志，确认MCP服务器启动
docker logs -f ragflow-server
```

你应该看到类似输出：

```
Starting MCP Server on 0.0.0.0:9382 with base URL http://127.0.0.1:9380...

__  __  ____ ____       ____  _____ ______     _______ ____
|  \/  |/ ___|  _ \     / ___|| ____|  _ \ \   / / ____|  _ \
| |\/| | |   | |_) |    \___ \|  _| | |_) \ \ / /|  _| | |_) |
| |  | | |___|  __/      ___) | |___|  _ < \ V / | |___|  _ <
|_|  |_|\____|_|        |____/|_____|_| \_\ \_/  |_____|_| \_\

MCP launch mode: self-host
MCP host: 0.0.0.0        ← 注意这里应该是 0.0.0.0
MCP port: 9382
```

### 步骤3: 验证端口映射

```bash
# 检查端口映射是否生效
docker ps | grep ragflow

# 应该看到类似输出：
# 0.0.0.0:9382->9382/tcp

# 测试宿主机能否访问MCP端口
curl http://127.0.0.1:9382/health
```

### 步骤4: 配置宿主机 Nginx

```bash
# 使用standalone配置（推荐）
sudo cp /home/user/ragflow/nginx_mcp_standalone.conf /etc/nginx/sites-available/mcp-ragflow

# 创建软链接
sudo ln -s /etc/nginx/sites-available/mcp-ragflow /etc/nginx/sites-enabled/

# 测试nginx配置
sudo nginx -t

# 重载nginx
sudo systemctl reload nginx
```

### 步骤5: 验证HTTPS访问

```bash
# 测试本地访问
curl http://127.0.0.1:9382/health

# 测试HTTPS访问
curl https://ddbmcp.xiaofeifei.fun/health

# 测试MCP端点
curl https://ddbmcp.xiaofeifei.fun/mcp \
  -H "Content-Type: application/json" \
  -X POST
```

## 配置对比

### ❌ 错误配置（无法访问）

```yaml
command:
  - --mcp-host=127.0.0.1    # ❌ 只监听容器内部
ports:
  # - ${SVR_MCP_PORT}:9382  # ❌ 端口映射被注释
```

结果：宿主机nginx无法访问容器内的MCP服务器

### ✅ 正确配置

```yaml
command:
  - --mcp-host=0.0.0.0      # ✅ 监听所有接口
ports:
  - ${SVR_MCP_PORT}:9382    # ✅ 端口映射启用
```

结果：宿主机nginx可以通过 `http://127.0.0.1:9382` 访问MCP服务器

## 故障排查

### 问题1: 宿主机无法访问9382端口

```bash
# 检查端口映射
docker ps | grep ragflow | grep 9382

# 如果没有输出，说明端口映射未生效
# 解决：检查docker-compose.yml中的端口映射配置
```

### 问题2: MCP监听地址错误

```bash
# 查看容器日志
docker logs ragflow-server | grep "MCP host"

# 应该看到: MCP host: 0.0.0.0
# 如果看到: MCP host: 127.0.0.1 ← 错误！需要修改docker-compose.yml
```

### 问题3: nginx无法连接到MCP

```bash
# 在宿主机测试MCP端口
curl -v http://127.0.0.1:9382/health

# 如果失败，检查：
# 1. Docker容器是否运行: docker ps | grep ragflow
# 2. 端口映射是否正确: docker port ragflow-server
# 3. 防火墙规则: sudo ufw status
```

### 问题4: HTTPS访问失败

```bash
# 测试nginx配置
sudo nginx -t

# 查看nginx错误日志
sudo tail -f /var/log/nginx/mcp_error.log

# 检查SSL证书
openssl x509 -in /home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/fullchain.cer -noout -dates
```

## 安全注意事项

### Docker容器端口暴露

修改为 `--mcp-host=0.0.0.0` 后，MCP服务器会监听容器的所有网络接口。但由于：

1. 端口映射 `9382:9382` 只映射到宿主机的 `127.0.0.1:9382`
2. 外部无法直接访问宿主机的9382端口
3. 只能通过nginx的HTTPS (443端口) 访问

如果你担心安全问题，可以修改端口映射：

```yaml
ports:
  # 只绑定到宿主机的localhost
  - 127.0.0.1:9382:9382
```

这样即使容器监听0.0.0.0，宿主机也只在localhost暴露端口。

### API密钥保护

确保 `--mcp-host-api-key` 使用强密钥：

```yaml
command:
  - --mcp-host-api-key=ragflow-your-strong-api-key-here
```

不要使用示例中的 `ragflow-kxxxxxxxxx`。

## 监控和日志

### Docker容器日志

```bash
# 实时查看MCP日志
docker logs -f ragflow-server

# 查看最近100行
docker logs --tail 100 ragflow-server

# 搜索MCP相关日志
docker logs ragflow-server 2>&1 | grep -i mcp
```

### Nginx日志

```bash
# 访问日志
sudo tail -f /var/log/nginx/mcp_access.log

# 错误日志
sudo tail -f /var/log/nginx/mcp_error.log
```

## 配置文件清单

项目根目录下的相关文件：

| 文件 | 用途 |
|------|------|
| `nginx_mcp_standalone.conf` | ✅ 推荐：独立nginx配置 |
| `nginx_mcp_simple.conf` | 简化版nginx配置 |
| `nginx_mcp_https.conf` | 完整版nginx配置 |
| `DOCKER_MCP_SETUP.md` | 本文档 |
| `MCP_SETUP_README.md` | 快速开始指南 |
| `MCP_HTTPS_DEPLOYMENT.md` | 详细部署文档 |

## 快速修改脚本

创建一个脚本自动修改配置：

```bash
#!/bin/bash
# 文件: fix_docker_mcp.sh

cd /home/user/ragflow/docker

echo "备份docker-compose.yml..."
cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)

echo "修改MCP监听地址..."
sed -i 's/--mcp-host=127\.0\.0\.1/--mcp-host=0.0.0.0/' docker-compose.yml

echo "启用端口映射..."
sed -i 's/^[[:space:]]*#[[:space:]]*-[[:space:]]*\${SVR_MCP_PORT}:9382/      - ${SVR_MCP_PORT}:9382/' docker-compose.yml

echo "验证修改..."
grep "mcp-host" docker-compose.yml
grep "SVR_MCP_PORT" docker-compose.yml

echo ""
echo "修改完成！请检查上面的输出确认修改正确。"
echo "如需应用修改，运行："
echo "  cd /home/user/ragflow/docker"
echo "  docker compose down"
echo "  docker compose up -d"
```

## 参考资料

- [RAGFlow MCP Server Documentation](./docs/develop/mcp/launch_mcp_server.md)
- [Docker Port Mapping](https://docs.docker.com/config/containers/container-networking/)
- [Nginx Reverse Proxy](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)

## 总结

关键修改点：

1. ✅ **docker-compose.yml**: `--mcp-host=0.0.0.0`
2. ✅ **docker-compose.yml**: `- ${SVR_MCP_PORT}:9382` (取消注释)
3. ✅ **宿主机nginx**: 反向代理到 `http://127.0.0.1:9382`

修改后架构：
```
外部 → HTTPS(443) → Nginx → HTTP(127.0.0.1:9382) → Docker端口映射 → 容器内MCP(0.0.0.0:9382)
```
