# RAGFlow MCP HTTPS 快速启动指南

## 快速开始 (5分钟)

### 1. 在宿主机上安装并配置 Nginx

```bash
# 安装 Nginx (Ubuntu/Debian)
sudo apt update && sudo apt install nginx -y

# 复制配置文件
sudo cp /home/user/ragflow/nginx_mcp_https.conf /etc/nginx/sites-available/ragflow-mcp
sudo ln -s /etc/nginx/sites-available/ragflow-mcp /etc/nginx/sites-enabled/

# 修改配置中的域名 (第19行)
sudo sed -i 's/mcp.xiaofeifei.fun/你的域名/g' /etc/nginx/sites-available/ragflow-mcp

# 测试并重载
sudo nginx -t && sudo systemctl reload nginx
```

### 2. 启动 RAGFlow 服务器

```bash
cd /home/user/ragflow
docker compose -f docker/docker-compose.yml up -d
```

### 3. 启动 MCP 服务器 (Host 模式)

```bash
cd /home/user/ragflow
./start_mcp_host_mode.sh
```

### 4. 测试连接

```bash
# 替换为你的域名和 API key
curl https://mcp.xiaofeifei.fun/
curl -H "Authorization: Bearer ragflow-YOUR-API-KEY" https://mcp.xiaofeifei.fun/sse
```

## 关键信息

| 项目 | 值 |
|-----|-----|
| MCP 监听地址 | 127.0.0.1:9382 (HTTP) |
| Nginx 监听地址 | 0.0.0.0:443 (HTTPS) |
| RAGFlow 地址 | 127.0.0.1:9380 (HTTP) |
| SSL 证书路径 | /home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/ |
| 运行模式 | host (多租户) |
| 传输协议 | SSE only |
| SSE 端点 | https://你的域名/sse |
| Messages 端点 | https://你的域名/messages/ |

## 客户端配置示例

### Claude Desktop

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

### Python MCP Client

```python
from mcp.client.sse import sse_client

async with sse_client(
    url="https://mcp.xiaofeifei.fun/sse",
    headers={"Authorization": "Bearer ragflow-YOUR-API-KEY"}
) as (read, write):
    # Your code here
    pass
```

## 常用命令

### 服务管理

```bash
# 启动 RAGFlow
cd /home/user/ragflow && docker compose -f docker/docker-compose.yml up -d

# 停止 RAGFlow
cd /home/user/ragflow && docker compose -f docker/docker-compose.yml down

# 启动 MCP 服务器
cd /home/user/ragflow && ./start_mcp_host_mode.sh

# 重启 Nginx
sudo systemctl reload nginx
```

### 日志查看

```bash
# RAGFlow 日志
docker logs -f ragflow-server

# MCP 日志 (在启动的终端查看)

# Nginx 日志
sudo tail -f /var/log/nginx/ragflow-mcp-access.log
sudo tail -f /var/log/nginx/ragflow-mcp-error.log
```

### 状态检查

```bash
# 检查 RAGFlow
curl http://127.0.0.1:9380/api/v1/health

# 检查 MCP 端口
netstat -tlnp | grep 9382

# 检查 Nginx
sudo systemctl status nginx
sudo nginx -t
```

## 故障排查速查

| 问题 | 检查命令 | 解决方法 |
|------|---------|---------|
| 502 Bad Gateway | `curl http://127.0.0.1:9382/` | 启动 MCP 服务器 |
| 401 Unauthorized | 检查 API key | 重新生成或检查 header 格式 |
| SSL 错误 | `sudo nginx -t` | 检查证书路径和权限 |
| 连接超时 | `netstat -tlnp \| grep 443` | 检查防火墙和端口 |

## 获取 API Key

1. 访问 RAGFlow: http://127.0.0.1 或 http://你的服务器IP
2. 登录后进入 **User Setting** → **API Key**
3. 点击 **Create API Key**
4. 复制生成的 key (格式: `ragflow-xxxxx`)

## 重要提示

⚠️ **Host 模式注意事项**:
- 每个客户端请求必须在 headers 中包含 `Authorization: Bearer ragflow-xxxxx`
- 仅支持 SSE 传输,不支持 Streamable-HTTP
- 不同客户端使用不同 API key 可以访问各自的数据集

🔒 **安全建议**:
- 仅在受信任的网络中使用
- 定期轮换 API keys
- 监控访问日志
- 使用 HTTPS 强制加密

📚 **完整文档**: 查看 `MCP_HTTPS_SETUP.md`

## 文件位置

- 启动脚本: `/home/user/ragflow/start_mcp_host_mode.sh`
- Nginx 配置: `/home/user/ragflow/nginx_mcp_https.conf`
- 完整指南: `/home/user/ragflow/MCP_HTTPS_SETUP.md`
- 快速指南: `/home/user/ragflow/QUICK_START.md` (本文件)
