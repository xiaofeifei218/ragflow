# RAGFlow MCP Server HTTPS Setup Guide

本指南帮助你配置 RAGFlow MCP 服务器通过宿主机 Nginx 进行 HTTPS 反向代理访问。

## 架构说明

```
客户端 (HTTPS)
    ↓
Nginx (宿主机 443端口, HTTPS)
    ↓
MCP Server (127.0.0.1:9382, HTTP)
    ↓
RAGFlow Server (127.0.0.1:9380, HTTP)
```

## 模式选择

RAGFlow MCP 服务器支持两种模式:

1. **Self-host 模式** (单租户):
   - 启动时提供 API key
   - 所有客户端共享同一个租户的数据
   - 支持 SSE 和 Streamable-HTTP 两种传输方式

2. **Host 模式** (多租户) ⭐ **推荐用于 HTTPS 反向代理**:
   - 启动时不需要 API key
   - 每个客户端请求必须在 headers 中提供自己的 API key
   - **仅支持 SSE 传输方式** (Streamable-HTTP 暂不支持)
   - 更适合多用户场景

## 前置要求

### 1. RAGFlow 服务器

确保 RAGFlow 服务器正在运行:

```bash
# 检查 RAGFlow 是否运行
curl http://127.0.0.1:9380/api/v1/health

# 如果没有运行,启动 RAGFlow
cd /home/user/ragflow
docker compose -f docker/docker-compose.yml up -d
```

### 2. 获取 API Key

客户端需要 RAGFlow API key 才能访问。获取方式:

1. 登录 RAGFlow Web 界面: http://127.0.0.1
2. 进入 **User Setting** → **API Key**
3. 点击 **Create API Key**
4. 复制生成的 API key (格式: `ragflow-xxxxx`)

详细说明: https://ragflow.io/docs/develop/acquire_ragflow_api_key

## 安装步骤

### 步骤 1: 安装 Nginx (在宿主机上)

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install nginx

# CentOS/RHEL
sudo yum install nginx

# 启动并设置开机自启
sudo systemctl start nginx
sudo systemctl enable nginx
```

### 步骤 2: 配置 Nginx HTTPS 反向代理

#### 2.1 复制 Nginx 配置文件

```bash
# 将生成的配置文件复制到 nginx 配置目录
sudo cp /home/user/ragflow/nginx_mcp_https.conf /etc/nginx/sites-available/ragflow-mcp

# 创建符号链接启用配置
sudo ln -s /etc/nginx/sites-available/ragflow-mcp /etc/nginx/sites-enabled/

# 如果你的系统没有 sites-available/sites-enabled 目录 (如 CentOS):
# sudo cp /home/user/ragflow/nginx_mcp_https.conf /etc/nginx/conf.d/ragflow-mcp.conf
```

#### 2.2 修改配置文件

编辑配置文件,根据你的实际情况修改:

```bash
sudo vi /etc/nginx/sites-available/ragflow-mcp
```

**必须修改的配置项**:

1. **域名** (第19行):
   ```nginx
   server_name mcp.xiaofeifei.fun;  # 改为你的实际域名或使用泛域名
   ```

2. **SSL 证书路径** (已经配置好,确认路径正确):
   ```nginx
   ssl_certificate /home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/fullchain.cer;
   ssl_certificate_key /home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/xiaofeifei.fun.key;
   ```

3. **MCP 服务器地址** (如果 MCP 运行在不同地址):
   ```nginx
   upstream ragflow_mcp_backend {
       server 127.0.0.1:9382;  # 默认本地 9382 端口
   }
   ```

#### 2.3 测试并重载 Nginx

```bash
# 测试配置文件语法
sudo nginx -t

# 如果测试通过,重载 Nginx
sudo systemctl reload nginx

# 查看 Nginx 状态
sudo systemctl status nginx
```

### 步骤 3: 启动 MCP 服务器 (Host 模式)

```bash
cd /home/user/ragflow

# 使用提供的启动脚本
./start_mcp_host_mode.sh
```

或者手动启动:

```bash
uv run mcp/server/server.py \
    --host=127.0.0.1 \
    --port=9382 \
    --base-url=http://127.0.0.1:9380 \
    --mode=host \
    --transport-sse-enabled \
    --no-transport-streamable-http-enabled
```

**启动成功标志**:

```
__  __  ____ ____       ____  _____ ______     _______ ____
|  \/  |/ ___|  _ \     / ___|| ____|  _ \ \   / / ____|  _ \
| |\/| | |   | |_) |    \___ \|  _| | |_) \ \ / /|  _| | |_) |
| |  | | |___|  __/      ___) | |___|  _ < \ V / | |___|  _ <
|_|  |_|\____|_|        |____/|_____|_| \_\ \_/  |_____|_| \_\

MCP launch mode: host
MCP host: 127.0.0.1
MCP port: 9382
MCP base_url: http://127.0.0.1:9380
SSE transport enabled: yes
SSE endpoint available at /sse
Streamable HTTP transport enabled: no
INFO:     Uvicorn running on http://127.0.0.1:9382 (Press CTRL+C to quit)
```

### 步骤 4: 配置 DNS (如果使用域名)

确保你的域名解析到宿主机 IP:

```bash
# 检查 DNS 解析
nslookup mcp.xiaofeifei.fun

# 或使用 hosts 文件 (测试用)
echo "127.0.0.1 mcp.xiaofeifei.fun" | sudo tee -a /etc/hosts
```

## 测试验证

### 1. 测试 HTTPS 访问

```bash
# 测试根路径
curl https://mcp.xiaofeifei.fun/
# 应该返回: RAGFlow MCP Server - HTTPS Proxy Active

# 测试 SSE 端点 (需要 API key)
curl -H "Authorization: Bearer ragflow-xxxxx" \
     https://mcp.xiaofeifei.fun/sse
```

### 2. 使用 MCP 客户端连接

创建客户端配置 (例如使用 Claude Desktop):

```json
{
  "mcpServers": {
    "ragflow": {
      "url": "https://mcp.xiaofeifei.fun/sse",
      "transport": "sse",
      "headers": {
        "Authorization": "Bearer ragflow-YOUR-API-KEY-HERE"
      }
    }
  }
}
```

### 3. 使用 Python 客户端测试

```python
from mcp.client.sse import sse_client

async def test_connection():
    async with sse_client(
        url="https://mcp.xiaofeifei.fun/sse",
        headers={"Authorization": "Bearer ragflow-YOUR-API-KEY-HERE"}
    ) as (read_stream, write_stream):
        print("Connected successfully!")
        # Your MCP client code here
```

## 故障排查

### 问题 1: Nginx 启动失败

```bash
# 检查配置语法
sudo nginx -t

# 查看错误日志
sudo tail -f /var/log/nginx/error.log
```

常见错误:
- **证书文件不存在**: 检查 SSL 证书路径是否正确
- **端口被占用**: 确认 80/443 端口未被其他服务占用

### 问题 2: SSL 证书错误

```bash
# 检查证书文件权限
ls -la /home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/

# 确保 Nginx 用户可以读取证书
sudo chmod 644 /home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/*.cer
sudo chmod 600 /home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/*.key
```

### 问题 3: MCP 连接失败

```bash
# 检查 MCP 服务器是否运行
ps aux | grep mcp

# 检查端口监听
netstat -tlnp | grep 9382

# 查看 MCP 日志
# (在 MCP 服务器终端查看输出)
```

### 问题 4: 401 Unauthorized

原因: API key 无效或未提供

解决:
1. 确认 API key 正确
2. 检查 Authorization header 格式: `Authorization: Bearer ragflow-xxxxx`
3. 确认 API key 对应的用户有权限访问数据集

### 问题 5: 502 Bad Gateway

原因: Nginx 无法连接到 MCP 服务器

解决:
```bash
# 检查 MCP 服务器是否运行
curl http://127.0.0.1:9382/

# 检查防火墙
sudo ufw status
```

## 安全建议

1. **使用强 API Key**: 定期轮换 API keys
2. **限制访问**: 配置 Nginx IP 白名单 (可选)
   ```nginx
   # 在 location 块中添加
   allow 192.168.1.0/24;  # 允许内网访问
   deny all;              # 拒绝其他所有访问
   ```
3. **启用 HTTPS**: 强制使用 HTTPS,禁止 HTTP 访问
4. **监控日志**: 定期检查 Nginx 和 MCP 日志
   ```bash
   sudo tail -f /var/log/nginx/ragflow-mcp-access.log
   sudo tail -f /var/log/nginx/ragflow-mcp-error.log
   ```

## 高级配置

### 使用 systemd 管理 MCP 服务器

创建 systemd 服务文件:

```bash
sudo vi /etc/systemd/system/ragflow-mcp.service
```

内容:

```ini
[Unit]
Description=RAGFlow MCP Server (Host Mode)
After=network.target

[Service]
Type=simple
User=yourusername
WorkingDirectory=/home/user/ragflow
ExecStart=/usr/bin/bash /home/user/ragflow/start_mcp_host_mode.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

启用服务:

```bash
sudo systemctl daemon-reload
sudo systemctl enable ragflow-mcp
sudo systemctl start ragflow-mcp
sudo systemctl status ragflow-mcp
```

### 配置 Nginx 日志轮转

```bash
sudo vi /etc/logrotate.d/ragflow-mcp
```

内容:

```
/var/log/nginx/ragflow-mcp-*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        if [ -f /var/run/nginx.pid ]; then
            kill -USR1 `cat /var/run/nginx.pid`
        fi
    endscript
}
```

## 参考资料

- [RAGFlow MCP 文档](https://ragflow.io/docs/develop/mcp/launch_mcp_server)
- [MCP 官方文档](https://modelcontextprotocol.io/)
- [Nginx 反向代理文档](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)

## 文件说明

本次配置创建的文件:

1. **start_mcp_host_mode.sh**: MCP 服务器启动脚本
2. **nginx_mcp_https.conf**: Nginx HTTPS 反向代理配置
3. **MCP_HTTPS_SETUP.md**: 本安装指南

位置: `/home/user/ragflow/`
