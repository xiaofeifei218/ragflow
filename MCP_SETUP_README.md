# RAGFlow MCP Server HTTPS 配置

本目录包含通过宿主机nginx反向代理启动RAGFlow MCP服务器(HTTPS)所需的所有配置文件。

## 🔀 部署模式选择

RAGFlow MCP服务器支持两种部署模式：

### 模式1: Docker模式 (推荐)

**适用场景**: MCP服务器随RAGFlow Docker容器一起启动

- ✅ **推荐使用** - 与RAGFlow集成,统一管理
- MCP服务器在Docker容器内运行
- 通过端口映射暴露到宿主机
- 配置文件: `docker/docker-compose.yml`

**快速开始**:

```bash
# 1. 修复Docker配置
./fix_docker_mcp.sh

# 2. 重启Docker容器
cd docker && docker compose down && docker compose up -d

# 3. 配置nginx
sudo cp nginx_mcp_standalone.conf /etc/nginx/sites-available/mcp-ragflow
sudo ln -s /etc/nginx/sites-available/mcp-ragflow /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 4. 测试
./test_docker_mcp.sh
```

**详细文档**: 👉 **[DOCKER_MCP_SETUP.md](./DOCKER_MCP_SETUP.md)**

### 模式2: 独立模式

**适用场景**: MCP服务器独立于RAGFlow Docker运行

- MCP服务器直接在宿主机运行
- 需要手动管理MCP进程
- 配置文件: `start_mcp_server.sh`

**快速开始**:

```bash
# 1. 设置API密钥
export RAGFLOW_API_KEY="ragflow-your-actual-api-key"

# 2. 启动MCP服务器
./start_mcp_server.sh

# 3. 配置nginx (同Docker模式)

# 4. 测试
./test_mcp_server.sh
```

**详细文档**: 👉 **[MCP_HTTPS_DEPLOYMENT.md](./MCP_HTTPS_DEPLOYMENT.md)**

---

## 📁 配置文件清单

### Docker模式文件

| 文件名 | 说明 | 模式 |
|--------|------|------|
| `fix_docker_mcp.sh` | Docker配置自动修复脚本 | Docker |
| `test_docker_mcp.sh` | Docker模式测试脚本 | Docker |
| `DOCKER_MCP_SETUP.md` | Docker模式详细文档 | Docker |

### 独立模式文件

| 文件名 | 说明 | 模式 |
|--------|------|------|
| `start_mcp_server.sh` | MCP服务器启动脚本 | 独立 |
| `install_mcp_https.sh` | 自动部署脚本 | 独立 |
| `test_mcp_server.sh` | 独立模式测试脚本 | 独立 |
| `ragflow-mcp.service` | Systemd服务模板 | 独立 |
| `MCP_HTTPS_DEPLOYMENT.md` | 独立模式详细文档 | 独立 |

### 通用文件

| 文件名 | 说明 | 模式 |
|--------|------|------|
| `nginx_mcp_standalone.conf` | ✅ 推荐nginx配置 | 通用 |
| `nginx_mcp_simple.conf` | 简化nginx配置 | 通用 |
| `nginx_mcp_https.conf` | 完整nginx配置 | 通用 |
| `MCP_SETUP_README.md` | 快速开始指南(本文档) | 通用 |

## 🚀 快速开始

> **注意**: 以下是**独立模式**的快速开始。如果你的MCP是在Docker中运行,请参考上面的**Docker模式**说明。

### 独立模式 - 方法一:自动安装(推荐)

```bash
# 1. 设置API密钥
export RAGFLOW_API_KEY="ragflow-your-actual-api-key"

# 2. 运行自动安装脚本
./install_mcp_https.sh
```

### 独立模式 - 方法二:手动安装

```bash
# 1. 设置API密钥
export RAGFLOW_API_KEY="ragflow-your-actual-api-key"

# 2. 安装nginx配置
sudo cp nginx_mcp_https.conf /etc/nginx/sites-available/mcp-ragflow
sudo ln -s /etc/nginx/sites-available/mcp-ragflow /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# 3. 启动MCP服务器
./start_mcp_server.sh
```

## 🔧 配置说明

### MCP服务器配置

- **监听地址**: 127.0.0.1 (仅本地,通过nginx访问)
- **端口**: 9382
- **模式**: self-host
- **RAGFlow URL**: http://127.0.0.1:9380

### Nginx反向代理配置

- **域名**: ddbmcp.xiaofeifei.fun
- **协议**: HTTPS (自动重定向HTTP到HTTPS)
- **SSL证书**: `/home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/`
- **端点**:
  - `/sse` - SSE传输(旧版)
  - `/mcp` - Streamable HTTP传输(推荐)
  - `/health` - 健康检查

## 📊 架构图

```
┌─────────────┐
│ MCP Client  │
└──────┬──────┘
       │ HTTPS
       ▼
┌─────────────────────────────┐
│ Nginx (宿主机:443)          │
│ ddbmcp.xiaofeifei.fun       │
└──────┬──────────────────────┘
       │ HTTP
       ▼
┌─────────────────────────────┐
│ MCP Server (127.0.0.1:9382) │
└──────┬──────────────────────┘
       │ HTTP
       ▼
┌─────────────────────────────┐
│ RAGFlow (127.0.0.1:9380)    │
└─────────────────────────────┘
```

## ✅ 验证部署

```bash
# 运行测试脚本
./test_mcp_server.sh

# 或手动测试
curl https://ddbmcp.xiaofeifei.fun/health
```

## 🛠️ 系统服务管理

如果使用systemd服务:

```bash
# 查看状态
sudo systemctl status ragflow-mcp

# 启动服务
sudo systemctl start ragflow-mcp

# 停止服务
sudo systemctl stop ragflow-mcp

# 重启服务
sudo systemctl restart ragflow-mcp

# 查看日志
sudo journalctl -u ragflow-mcp -f
```

## 📝 日志位置

- **MCP服务器日志**:
  - 直接运行: 标准输出
  - Systemd服务: `sudo journalctl -u ragflow-mcp -f`

- **Nginx日志**:
  - 访问日志: `/var/log/nginx/mcp_access.log`
  - 错误日志: `/var/log/nginx/mcp_error.log`

## 🔒 安全特性

1. **MCP服务器仅监听本地**
   - 绑定到 127.0.0.1,不直接暴露在公网

2. **HTTPS加密**
   - 所有外部通信使用TLS 1.2+加密
   - 启用OCSP Stapling

3. **安全头部**
   - HSTS (强制HTTPS)
   - X-Frame-Options
   - X-Content-Type-Options
   - X-XSS-Protection

4. **API密钥认证**
   - Self-host模式使用服务器端API密钥

## 🌐 客户端连接

### MCP服务器URL

```
https://ddbmcp.xiaofeifei.fun/mcp
```

### 传输协议

- **推荐**: Streamable HTTP (`/mcp`)
- **旧版**: SSE (`/sse`,将于2025-03-26弃用)

### Python客户端示例

```python
import requests

url = "https://ddbmcp.xiaofeifei.fun/mcp"
response = requests.post(url, json={
    "method": "list_datasets"
})
print(response.json())
```

### Claude Desktop配置

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

## 📖 详细文档

完整的部署指南、故障排查和维护说明,请参阅:

👉 **[MCP_HTTPS_DEPLOYMENT.md](./MCP_HTTPS_DEPLOYMENT.md)**

## ❓ 常见问题

### 如何获取RAGFlow API密钥?

1. 登录RAGFlow Web界面
2. 进入 Settings → API Keys
3. 创建或复制现有API密钥

### MCP服务器无法启动?

检查:
- RAGFlow服务器是否运行: `curl http://127.0.0.1:9380/api/v1/system/status`
- API密钥是否正确: `echo $RAGFLOW_API_KEY`
- 端口9382是否被占用: `sudo lsof -i :9382`

### HTTPS无法访问?

检查:
- DNS是否解析: `dig ddbmcp.xiaofeifei.fun`
- 防火墙规则: `sudo ufw status`
- Nginx配置: `sudo nginx -t`
- SSL证书: `openssl x509 -in /home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/fullchain.cer -noout -dates`

## 📚 参考资料

- [RAGFlow官方文档](https://ragflow.io/docs)
- [MCP协议规范](https://modelcontextprotocol.io/)
- [Nginx反向代理文档](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)

## 🤝 支持

如有问题,请查看:
- RAGFlow GitHub: https://github.com/infiniflow/ragflow/issues
- 详细文档: [MCP_HTTPS_DEPLOYMENT.md](./MCP_HTTPS_DEPLOYMENT.md)

---

**部署时间**: $(date)
**版本**: RAGFlow v0.18.0+
**域名**: ddbmcp.xiaofeifei.fun
