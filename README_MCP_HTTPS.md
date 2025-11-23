# RAGFlow MCP Server HTTPS 配置

本配置帮助你通过宿主机 Nginx 反向代理,使用 HTTPS 访问 RAGFlow MCP 服务器。

## 📁 配置文件说明

### 1. `start_mcp_host_mode.sh` - MCP 服务器启动脚本
**用途**: 以 host 模式启动 MCP 服务器

**特性**:
- 运行在 127.0.0.1:9382
- Host 模式 (多租户,需要客户端提供 API key)
- 仅启用 SSE 传输 (Streamable-HTTP 在 host 模式下不支持)
- 包含健康检查

**使用方法**:
```bash
cd /home/user/ragflow
./start_mcp_host_mode.sh
```

### 2. `nginx_mcp_https.conf` - Nginx HTTPS 反向代理配置
**用途**: Nginx 配置文件,用于 HTTPS 反向代理

**特性**:
- HTTPS/TLS 1.2/1.3 支持
- 使用你的 SSL 证书 (xiaofeifei.fun)
- SSE 长连接优化
- 安全头部配置
- HTTP 到 HTTPS 自动重定向

**安装位置**:
```bash
# Ubuntu/Debian
sudo cp nginx_mcp_https.conf /etc/nginx/sites-available/ragflow-mcp
sudo ln -s /etc/nginx/sites-available/ragflow-mcp /etc/nginx/sites-enabled/

# CentOS/RHEL
sudo cp nginx_mcp_https.conf /etc/nginx/conf.d/ragflow-mcp.conf
```

**需要修改的配置**:
- Line 19: `server_name` - 改为你的实际域名
- Line 22-23: SSL 证书路径 (已配置为你的证书路径)

### 3. `MCP_HTTPS_SETUP.md` - 完整安装指南
**用途**: 详细的安装和配置指南

**包含内容**:
- 架构说明
- 模式选择 (self-host vs host)
- 前置要求
- 详细安装步骤
- 测试验证方法
- 故障排查
- 安全建议
- 高级配置 (systemd 服务)

### 4. `QUICK_START.md` - 快速启动指南
**用途**: 5分钟快速上手

**包含内容**:
- 快速安装命令
- 关键配置信息表
- 客户端配置示例
- 常用命令速查
- 故障排查速查表

### 5. `README_MCP_HTTPS.md` - 本文件
配置文件总览和下一步指引

## 🚀 快速开始

### 方案一: 详细步骤 (推荐首次使用)

1. **阅读完整指南**:
   ```bash
   cat MCP_HTTPS_SETUP.md
   ```

2. **按照指南逐步操作**

### 方案二: 快速启动 (熟悉流程后使用)

1. **阅读快速指南**:
   ```bash
   cat QUICK_START.md
   ```

2. **执行快速启动命令**

## 📋 配置检查清单

在开始之前,确认以下项目:

- [ ] RAGFlow 服务器已安装并运行 (http://127.0.0.1:9380)
- [ ] 已获取 RAGFlow API key
- [ ] 宿主机已安装 Nginx
- [ ] SSL 证书文件存在且可访问:
  - `/home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/fullchain.cer`
  - `/home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc/xiaofeifei.fun.key`
- [ ] 域名 DNS 已解析到宿主机 IP (或配置了 hosts)
- [ ] 防火墙已开放 80 和 443 端口

## 🔧 架构图

```
┌─────────────┐
│   客户端     │
│ (MCP Client)│
└──────┬──────┘
       │ HTTPS (443)
       │ Authorization: Bearer ragflow-xxxxx
       ↓
┌─────────────────────────┐
│   宿主机 Nginx          │
│   反向代理 (HTTPS)       │
│   - SSL/TLS 终止         │
│   - 请求转发             │
└──────┬──────────────────┘
       │ HTTP (9382)
       ↓
┌─────────────────────────┐
│   MCP Server            │
│   - Host 模式            │
│   - SSE 传输             │
│   - 127.0.0.1:9382      │
└──────┬──────────────────┘
       │ HTTP (9380)
       ↓
┌─────────────────────────┐
│   RAGFlow Server        │
│   - API 服务             │
│   - 127.0.0.1:9380      │
└─────────────────────────┘
```

## 🎯 关键配置参数

| 配置项 | 值 | 说明 |
|--------|-----|------|
| MCP 监听地址 | 127.0.0.1:9382 | 仅本地访问 |
| MCP 运行模式 | host | 多租户模式 |
| 传输协议 | SSE only | /sse 端点 |
| Nginx 监听端口 | 443 (HTTPS) | 公网访问 |
| SSL 证书 | xiaofeifei.fun | ECC 证书 |
| RAGFlow 地址 | http://127.0.0.1:9380 | MCP 连接目标 |

## 📝 使用示例

### 启动服务

```bash
# 1. 启动 RAGFlow (如果未运行)
cd /home/user/ragflow
docker compose -f docker/docker-compose.yml up -d

# 2. 在宿主机配置并启动 Nginx
sudo cp nginx_mcp_https.conf /etc/nginx/sites-available/ragflow-mcp
sudo ln -s /etc/nginx/sites-available/ragflow-mcp /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 3. 启动 MCP 服务器
./start_mcp_host_mode.sh
```

### 客户端连接示例

#### Claude Desktop 配置

编辑 `~/Library/Application Support/Claude/claude_desktop_config.json`:

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

#### Python 代码示例

```python
from mcp.client.sse import sse_client
import asyncio

async def query_ragflow():
    headers = {
        "Authorization": "Bearer ragflow-YOUR-API-KEY"
    }

    async with sse_client(
        url="https://mcp.xiaofeifei.fun/sse",
        headers=headers
    ) as (read_stream, write_stream):
        # 使用 MCP 客户端
        # 例如: 列出工具, 调用检索等
        print("Connected to RAGFlow MCP Server!")

if __name__ == "__main__":
    asyncio.run(query_ragflow())
```

## 🔍 测试验证

### 基础测试

```bash
# 1. 测试根路径
curl https://mcp.xiaofeifei.fun/
# 期望输出: RAGFlow MCP Server - HTTPS Proxy Active

# 2. 测试 SSE 端点 (需要替换 API key)
curl -H "Authorization: Bearer ragflow-xxxxx" \
     https://mcp.xiaofeifei.fun/sse
```

### 详细测试

```bash
# 测试 SSL 证书
openssl s_client -connect mcp.xiaofeifei.fun:443 -servername mcp.xiaofeifei.fun

# 测试 HTTP 重定向
curl -I http://mcp.xiaofeifei.fun/
# 期望: 301 redirect 到 HTTPS

# 测试响应头
curl -I https://mcp.xiaofeifei.fun/
# 检查安全头部: HSTS, X-Frame-Options 等
```

## 🛠️ 维护和监控

### 日志位置

```bash
# Nginx 访问日志
sudo tail -f /var/log/nginx/ragflow-mcp-access.log

# Nginx 错误日志
sudo tail -f /var/log/nginx/ragflow-mcp-error.log

# MCP 服务器日志
# (在启动 MCP 的终端查看实时输出)

# RAGFlow 日志
docker logs -f ragflow-server
```

### 性能监控

```bash
# 查看 Nginx 连接状态
sudo netstat -anp | grep :443 | wc -l

# 查看 MCP 进程
ps aux | grep "mcp/server/server.py"

# 查看系统资源
top -p $(pgrep -f "mcp/server/server.py")
```

## ⚠️ 重要提示

### Host 模式特性

1. **每个请求必须包含 API key**:
   - Header: `Authorization: Bearer ragflow-xxxxx`

2. **仅支持 SSE 传输**:
   - 端点: `/sse`
   - 不支持 `/mcp` (Streamable-HTTP)

3. **多租户隔离**:
   - 不同 API key 访问不同租户的数据
   - 确保 API key 安全性

### 安全建议

1. **API Key 管理**:
   - 定期轮换
   - 不要硬编码在代码中
   - 使用环境变量或配置文件

2. **网络安全**:
   - 只暴露 HTTPS 端口 (443)
   - 考虑使用 IP 白名单
   - 启用 fail2ban 防止暴力破解

3. **证书管理**:
   - 定期更新 SSL 证书
   - 监控证书过期时间

4. **日志审计**:
   - 定期检查访问日志
   - 监控异常访问模式

## 📚 相关文档

- [RAGFlow 官方文档](https://ragflow.io/docs)
- [MCP 启动指南](https://ragflow.io/docs/develop/mcp/launch_mcp_server)
- [MCP 协议文档](https://modelcontextprotocol.io/)
- [Nginx 文档](https://nginx.org/en/docs/)

## 🤝 获取帮助

如果遇到问题:

1. 查看 `MCP_HTTPS_SETUP.md` 的故障排查章节
2. 检查日志文件
3. 访问 RAGFlow GitHub Issues: https://github.com/infiniflow/ragflow/issues

## 📄 文件清单

```
/home/user/ragflow/
├── start_mcp_host_mode.sh      # MCP 启动脚本
├── nginx_mcp_https.conf        # Nginx 配置文件
├── MCP_HTTPS_SETUP.md          # 完整安装指南
├── QUICK_START.md              # 快速启动指南
└── README_MCP_HTTPS.md         # 本文件
```

## 🔄 下一步

1. **首次使用**: 阅读 `MCP_HTTPS_SETUP.md`
2. **快速启动**: 阅读 `QUICK_START.md`
3. **问题排查**: 查看各文档的故障排查章节
4. **生产部署**: 考虑使用 systemd 服务化 (见 MCP_HTTPS_SETUP.md)

---

**配置创建时间**: 2025-11-23
**RAGFlow 版本**: v0.22.0+
**MCP 协议**: SSE Transport (Host Mode)
