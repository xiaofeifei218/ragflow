# 如何将RAGFlow MCP服务器配置到Claude Desktop App

本指南详细说明如何将RAGFlow MCP服务器集成到Claude Desktop应用中。

## 📋 前提条件

1. **RAGFlow MCP服务器已启动**
2. **知道MCP服务器的访问地址**
3. **已安装Claude Desktop App**

---

## 🚀 第一步：启动MCP服务器

### 选项A：Docker模式（推荐）

如果你的MCP是在Docker中运行，需要先启用它。

#### 1. 修改docker-compose.yml

编辑 `docker/docker-compose.yml`，取消MCP配置的注释：

```yaml
services:
  ragflow-cpu:
    image: ${RAGFLOW_IMAGE}
    command:                           # ← 取消这些行的注释
      - --enable-mcpserver            # ← 取消注释
      - --mcp-host=0.0.0.0            # ← 取消注释
      - --mcp-port=9382               # ← 取消注释
      - --mcp-base-url=http://127.0.0.1:9380  # ← 取消注释
      - --mcp-script-path=/ragflow/mcp/server/server.py  # ← 取消注释
      - --mcp-mode=self-host          # ← 取消注释
      - --mcp-host-api-key=ragflow-YOUR-ACTUAL-API-KEY  # ← 取消注释并填入真实API密钥
    ports:
      - ${SVR_MCP_PORT}:9382          # ← 确保没有被注释
```

**重要修改点**：
- `--mcp-host=0.0.0.0` - 允许外部访问
- `--mcp-host-api-key=ragflow-YOUR-ACTUAL-API-KEY` - 替换为你的真实API密钥

#### 2. 获取API密钥

```bash
# 登录RAGFlow Web界面
# 导航到: Settings → API Keys
# 创建或复制现有API密钥
```

#### 3. 重启Docker容器

```bash
cd docker
docker compose down
docker compose up -d

# 查看日志确认MCP启动
docker logs -f ragflow-server | grep MCP
```

你应该看到：
```
MCP host: 0.0.0.0
MCP port: 9382
MCP launch mode: self-host
```

---

## 🔧 第二步：配置Claude Desktop

### 方法1：局域网访问（最简单）

如果Claude Desktop和MCP服务器在同一局域网内，这是最简单的方案。

#### 1. 找到Claude Desktop配置文件

**macOS**:
```bash
~/Library/Application Support/Claude/claude_desktop_config.json
```

**Windows**:
```
%APPDATA%\Claude\claude_desktop_config.json
```

**Linux**:
```bash
~/.config/Claude/claude_desktop_config.json
```

#### 2. 编辑配置文件

添加RAGFlow MCP服务器配置：

```json
{
  "mcpServers": {
    "ragflow": {
      "command": "curl",
      "args": [
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "http://YOUR_SERVER_IP:9382/mcp"
      ],
      "env": {}
    }
  }
}
```

**替换说明**：
- `YOUR_SERVER_IP` - 替换为你的服务器局域网IP地址
  - 查看服务器IP: `ip addr show` 或 `hostname -I`
  - 例如: `192.168.1.100`

**完整示例**：
```json
{
  "mcpServers": {
    "ragflow": {
      "command": "curl",
      "args": [
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "http://192.168.1.100:9382/mcp"
      ],
      "env": {}
    }
  }
}
```

#### 3. 重启Claude Desktop

- 完全退出Claude Desktop
- 重新启动应用

---

### 方法2：使用SSE传输（备选方案）

如果streamable-http不工作，可以尝试SSE传输：

```json
{
  "mcpServers": {
    "ragflow": {
      "command": "curl",
      "args": [
        "-N",
        "-H", "Accept: text/event-stream",
        "http://YOUR_SERVER_IP:9382/sse"
      ],
      "env": {}
    }
  }
}
```

---

### 方法3：使用HTTPS（需要配置nginx）

如果你已经配置了nginx反向代理和HTTPS：

```json
{
  "mcpServers": {
    "ragflow": {
      "command": "curl",
      "args": [
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "https://YOUR_DOMAIN/mcp"
      ],
      "env": {}
    }
  }
}
```

**如果使用自签名证书**，添加 `-k` 参数：

```json
{
  "mcpServers": {
    "ragflow": {
      "command": "curl",
      "args": [
        "-k",
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "https://YOUR_DOMAIN/mcp"
      ],
      "env": {}
    }
  }
}
```

---

## 🧪 第三步：测试MCP连接

### 1. 在服务器上测试

```bash
# 测试MCP端点
curl -X POST http://localhost:9382/mcp

# 测试SSE端点
curl -N http://localhost:9382/sse
```

### 2. 在Claude Desktop中测试

打开Claude Desktop后：

1. 查看设置或工具栏，应该能看到 "ragflow" MCP服务器
2. 尝试使用RAGFlow的功能（如搜索知识库）
3. 查看Claude Desktop的开发者工具/日志（如果有）

### 3. 常见问题排查

#### 问题1: 连接被拒绝

```bash
# 检查MCP服务器是否运行
curl http://YOUR_SERVER_IP:9382/mcp

# 检查防火墙
sudo ufw status
sudo ufw allow 9382/tcp  # 如果需要
```

#### 问题2: Claude Desktop找不到MCP服务器

1. 检查配置文件路径是否正确
2. 检查JSON格式是否有效（使用JSON验证器）
3. 完全退出并重启Claude Desktop

#### 问题3: 无法访问局域网IP

```bash
# 确保服务器在同一网络
ping YOUR_SERVER_IP

# 检查Docker端口映射
docker ps | grep ragflow
# 应该看到: 0.0.0.0:9382->9382/tcp
```

---

## 📱 不同网络场景的配置

### 场景1: 同一台机器（本地开发）

```json
{
  "mcpServers": {
    "ragflow": {
      "command": "curl",
      "args": [
        "-X", "POST",
        "http://127.0.0.1:9382/mcp"
      ]
    }
  }
}
```

### 场景2: 局域网（推荐家庭/办公室）

```json
{
  "mcpServers": {
    "ragflow": {
      "command": "curl",
      "args": [
        "-X", "POST",
        "http://192.168.1.100:9382/mcp"
      ]
    }
  }
}
```

### 场景3: 公网访问（需要域名和HTTPS）

```json
{
  "mcpServers": {
    "ragflow": {
      "command": "curl",
      "args": [
        "-X", "POST",
        "https://ddbmcp.xiaofeifei.fun/mcp"
      ]
    }
  }
}
```

### 场景4: 通过VPN访问

```json
{
  "mcpServers": {
    "ragflow": {
      "command": "curl",
      "args": [
        "-X", "POST",
        "http://10.0.0.100:9382/mcp"
      ]
    }
  }
}
```

---

## 🔐 安全建议

### 1. 局域网部署（推荐）

**优点**：
- ✅ 不需要HTTPS证书
- ✅ 不需要公网域名
- ✅ 更安全（仅局域网访问）
- ✅ 配置简单

**适用场景**：
- 家庭网络
- 办公室内网
- VPN连接

### 2. 公网部署

**需要**：
- ✅ 配置HTTPS（nginx反向代理）
- ✅ 有效的SSL证书
- ✅ 配置防火墙规则
- ✅ 考虑API密钥安全

**参考文档**：
- [DOCKER_MCP_SETUP.md](./DOCKER_MCP_SETUP.md) - Docker HTTPS配置
- [NGINX_SETUP_GUIDE.md](./NGINX_SETUP_GUIDE.md) - Nginx配置指南

---

## 📝 完整配置示例

### 示例1: 局域网 + Docker模式

**1. docker-compose.yml**:
```yaml
services:
  ragflow-cpu:
    command:
      - --enable-mcpserver
      - --mcp-host=0.0.0.0
      - --mcp-port=9382
      - --mcp-base-url=http://127.0.0.1:9380
      - --mcp-script-path=/ragflow/mcp/server/server.py
      - --mcp-mode=self-host
      - --mcp-host-api-key=ragflow-abc123xyz
    ports:
      - 9382:9382
```

**2. Claude Desktop配置** (`claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "ragflow-local": {
      "command": "curl",
      "args": [
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "http://192.168.1.100:9382/mcp"
      ]
    }
  }
}
```

**3. 测试**:
```bash
# 服务器端
curl -X POST http://192.168.1.100:9382/mcp

# 重启Claude Desktop
```

---

## 🐛 故障排查步骤

### 步骤1: 验证MCP服务器运行

```bash
# 在服务器上测试
curl -v http://localhost:9382/mcp

# 如果失败，检查Docker容器
docker logs ragflow-server | grep MCP

# 检查端口监听
sudo lsof -i :9382
```

### 步骤2: 验证网络连通性

```bash
# 从Claude Desktop所在机器测试
ping YOUR_SERVER_IP

# 测试端口
telnet YOUR_SERVER_IP 9382
# 或
nc -zv YOUR_SERVER_IP 9382
```

### 步骤3: 检查Claude Desktop配置

```bash
# 验证JSON格式
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | python -m json.tool

# 检查是否有语法错误
```

### 步骤4: 查看Claude Desktop日志

**macOS**:
```bash
~/Library/Logs/Claude/
```

**Windows**:
```
%APPDATA%\Claude\logs\
```

---

## 📚 相关文档

- [DOCKER_MCP_SETUP.md](./DOCKER_MCP_SETUP.md) - Docker模式完整配置
- [MCP_SETUP_README.md](./MCP_SETUP_README.md) - 快速开始指南
- [NGINX_SETUP_GUIDE.md](./NGINX_SETUP_GUIDE.md) - Nginx配置详解
- [RAGFlow MCP Documentation](./docs/develop/mcp/launch_mcp_server.md) - 官方文档

---

## 💡 快速命令参考

```bash
# === 启动MCP服务器 ===

# Docker模式
cd docker
docker compose down && docker compose up -d
docker logs -f ragflow-server | grep MCP

# === 测试连接 ===

# 本地测试
curl -X POST http://localhost:9382/mcp

# 远程测试
curl -X POST http://YOUR_SERVER_IP:9382/mcp

# === Claude Desktop ===

# 编辑配置文件 (macOS)
nano ~/Library/Application\ Support/Claude/claude_desktop_config.json

# 验证JSON格式
python -m json.tool claude_desktop_config.json

# === 网络调试 ===

# 查看服务器IP
hostname -I

# 检查端口
sudo lsof -i :9382

# 测试连通性
ping YOUR_SERVER_IP
telnet YOUR_SERVER_IP 9382
```

---

## ✅ 成功标志

配置成功后，你应该能在Claude Desktop中：

1. ✅ 看到 "ragflow" MCP服务器已连接
2. ✅ 使用RAGFlow的工具和功能
3. ✅ 搜索知识库
4. ✅ 检索文档

如有问题，请按照故障排查步骤逐步检查！
