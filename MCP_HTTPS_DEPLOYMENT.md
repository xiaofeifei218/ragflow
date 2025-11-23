# RAGFlow MCP Server HTTPS Deployment Guide

本文档说明如何通过宿主机nginx反向代理启动RAGFlow MCP服务器,使用HTTPS协议。

## 架构概览

```
[MCP Client]
    ↓ HTTPS
[nginx (宿主机:443)] → ddbmcp.xiaofeifei.fun
    ↓ HTTP
[MCP Server (localhost:9382)]
    ↓ HTTP
[RAGFlow Server (localhost:9380)]
```

## 前提条件

1. **RAGFlow服务器运行中**
   - RAGFlow v0.18.0+已启动并运行在 http://127.0.0.1:9380
   - 验证: `curl http://127.0.0.1:9380/api/v1/system/status`

2. **RAGFlow API密钥**
   - 登录RAGFlow Web界面
   - 进入 Settings → API Keys
   - 创建或复制现有API密钥

3. **Python环境**
   - Python 3.10-3.12
   - uv包管理器已安装
   - 项目依赖已安装: `uv sync --python 3.10 --all-extras`

4. **Nginx已安装**
   - 宿主机已安装nginx
   - 验证: `sudo nginx -v`

5. **SSL证书**
   - 证书位置: `/home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/`
   - 已配置泛域名证书

## 部署步骤

### 步骤 1: 设置API密钥

设置环境变量:

```bash
export RAGFLOW_API_KEY="ragflow-your-actual-api-key"
```

或者直接编辑 `start_mcp_server.sh` 文件,替换API密钥。

### 步骤 2: 配置Nginx

1. **复制nginx配置到系统目录**:

```bash
sudo cp nginx_mcp_https.conf /etc/nginx/sites-available/mcp-ragflow
```

2. **创建软链接启用配置**:

```bash
sudo ln -s /etc/nginx/sites-available/mcp-ragflow /etc/nginx/sites-enabled/
```

3. **检查nginx配置**:

```bash
sudo nginx -t
```

应该看到:
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

4. **重载nginx**:

```bash
sudo systemctl reload nginx
```

或者:

```bash
sudo nginx -s reload
```

### 步骤 3: 启动MCP服务器

1. **赋予脚本执行权限**:

```bash
chmod +x start_mcp_server.sh
```

2. **启动MCP服务器**:

```bash
./start_mcp_server.sh
```

或者使用systemd服务(推荐生产环境):

创建 `/etc/systemd/system/ragflow-mcp.service`:

```ini
[Unit]
Description=RAGFlow MCP Server
After=network.target

[Service]
Type=simple
User=xiaofeifei
WorkingDirectory=/home/user/ragflow
Environment="RAGFLOW_API_KEY=ragflow-your-actual-key"
ExecStart=/home/user/ragflow/start_mcp_server.sh
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

然后启动服务:

```bash
sudo systemctl daemon-reload
sudo systemctl enable ragflow-mcp
sudo systemctl start ragflow-mcp
sudo systemctl status ragflow-mcp
```

### 步骤 4: 验证部署

1. **检查MCP服务器日志**:

应该看到类似输出:
```
Starting MCP Server on 127.0.0.1:9382 with base URL http://127.0.0.1:9380...

__  __  ____ ____       ____  _____ ______     _______ ____
|  \/  |/ ___|  _ \     / ___|| ____|  _ \ \   / / ____|  _ \
| |\/| | |   | |_) |    \___ \|  _| | |_) \ \ / /|  _| | |_) |
| |  | | |___|  __/      ___) | |___|  _ < \ V / | |___|  _ <
|_|  |_|\____|_|        |____/|_____|_| \_\ \_/  |_____|_| \_\

MCP launch mode: self-host
MCP host: 127.0.0.1
MCP port: 9382
MCP base_url: http://127.0.0.1:9380
INFO:     Started server process
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://127.0.0.1:9382
```

2. **测试本地MCP服务器**:

```bash
curl http://127.0.0.1:9382/health
```

3. **测试HTTPS访问**:

```bash
curl https://ddbmcp.xiaofeifei.fun/health
```

4. **测试SSE端点**:

```bash
curl -H "Authorization: Bearer ragflow-your-api-key" \
     https://ddbmcp.xiaofeifei.fun/sse
```

5. **测试Streamable HTTP端点**:

```bash
curl -H "Authorization: Bearer ragflow-your-api-key" \
     -H "Content-Type: application/json" \
     -X POST \
     https://ddbmcp.xiaofeifei.fun/mcp
```

## MCP传输协议

RAGFlow MCP服务器支持两种传输协议:

### 1. SSE传输 (旧版,已弃用)
- 端点: `/sse`
- 发布日期: 2024-11-05
- 弃用日期: 2025-03-26
- 用途: 服务器推送事件(Server-Sent Events)

### 2. Streamable HTTP传输 (推荐)
- 端点: `/mcp`
- 用途: 现代化的流式HTTP传输
- 支持JSON响应

## 客户端连接示例

### 使用Python客户端

```python
import requests

# MCP服务器URL
MCP_URL = "https://ddbmcp.xiaofeifei.fun/mcp"

# API密钥(self-host模式已在服务器配置,客户端无需提供)
headers = {
    "Content-Type": "application/json"
}

# 发送请求
response = requests.post(MCP_URL, headers=headers, json={
    "method": "list_datasets"
})

print(response.json())
```

### 使用Claude Desktop配置

在Claude Desktop的配置文件中添加:

```json
{
  "mcpServers": {
    "ragflow": {
      "url": "https://ddbmcp.xiaofeifei.fun/mcp",
      "transport": "streamable-http"
    }
  }
}
```

## 安全考虑

1. **MCP服务器绑定到localhost**
   - 服务器只监听 `127.0.0.1:9382`
   - 不直接暴露在公网,只能通过nginx访问
   - 提高安全性,防止直接攻击

2. **HTTPS加密**
   - 所有外部通信都经过TLS加密
   - 使用现代化的SSL配置(TLSv1.2+)
   - 启用OCSP Stapling

3. **API密钥认证**
   - Self-host模式:API密钥在服务器启动时配置
   - Host模式:客户端请求需包含API密钥

4. **安全头部**
   - HSTS (强制HTTPS)
   - X-Frame-Options (防止点击劫持)
   - X-Content-Type-Options (防止MIME嗅探)
   - X-XSS-Protection

## 故障排查

### MCP服务器无法启动

1. 检查RAGFlow服务器是否运行:
   ```bash
   curl http://127.0.0.1:9380/api/v1/system/status
   ```

2. 检查API密钥是否正确:
   ```bash
   echo $RAGFLOW_API_KEY
   ```

3. 检查端口9382是否被占用:
   ```bash
   sudo lsof -i :9382
   ```

### Nginx报错

1. 检查SSL证书路径是否正确:
   ```bash
   ls -la /home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/
   ```

2. 检查nginx配置语法:
   ```bash
   sudo nginx -t
   ```

3. 查看nginx错误日志:
   ```bash
   sudo tail -f /var/log/nginx/mcp_error.log
   ```

### 无法通过HTTPS访问

1. 检查防火墙规则:
   ```bash
   sudo ufw status
   # 如果443端口未开放:
   sudo ufw allow 443/tcp
   ```

2. 检查DNS解析:
   ```bash
   dig ddbmcp.xiaofeifei.fun
   nslookup ddbmcp.xiaofeifei.fun
   ```

3. 测试本地访问:
   ```bash
   curl -k https://localhost/health --resolve ddbmcp.xiaofeifei.fun:443:127.0.0.1
   ```

### SSL证书问题

1. 检查证书有效期:
   ```bash
   openssl x509 -in /home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/fullchain.cer -noout -dates
   ```

2. 验证证书链:
   ```bash
   openssl verify -CAfile /home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/ca.cer \
                  /home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/fullchain.cer
   ```

## 日志位置

- **MCP服务器日志**:
  - 标准输出(如果直接运行)
  - systemd journal: `sudo journalctl -u ragflow-mcp -f`

- **Nginx访问日志**: `/var/log/nginx/mcp_access.log`
- **Nginx错误日志**: `/var/log/nginx/mcp_error.log`

## 性能优化

### Nginx优化

1. 调整worker进程数:
   ```nginx
   worker_processes auto;
   ```

2. 调整连接数:
   ```nginx
   events {
       worker_connections 2048;
   }
   ```

3. 启用缓存(如果需要):
   ```nginx
   proxy_cache_path /var/cache/nginx/mcp levels=1:2 keys_zone=mcp_cache:10m;
   ```

### MCP服务器优化

根据负载调整超时设置:
- 开发环境: 较短超时(3600s)
- 生产环境: 较长超时(86400s)用于SSE

## 维护

### 更新SSL证书

证书更新后,重载nginx:

```bash
sudo nginx -s reload
```

### 备份配置

定期备份:
```bash
cp /etc/nginx/sites-available/mcp-ragflow ~/backups/mcp-ragflow-$(date +%Y%m%d).conf
```

### 监控

使用监控工具监控:
- MCP服务器健康状态
- Nginx访问日志
- SSL证书有效期
- 系统资源使用

## 参考文档

- [RAGFlow MCP Server Documentation](./docs/develop/mcp/launch_mcp_server.md)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [Nginx Reverse Proxy Guide](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)

## 支持

如有问题,请查看:
- RAGFlow GitHub Issues: https://github.com/infiniflow/ragflow/issues
- RAGFlow文档: https://ragflow.io/docs
