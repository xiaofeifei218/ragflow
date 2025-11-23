# Nginx 配置管理指南

## 问题1: `ln -s` 软链接是什么？

### 命令解释

```bash
sudo ln -s /etc/nginx/sites-available/mcp-ragflow /etc/nginx/sites-enabled/
```

- `ln` = link（创建链接）
- `-s` = symbolic（符号链接，软链接）
- 第一个路径 = 源文件（实际的配置文件）
- 第二个路径 = 链接位置（快捷方式）

### 图解

```
/etc/nginx/
│
├── sites-available/           ← 配置文件仓库（所有配置都放这里）
│   ├── default               ← nginx默认配置
│   ├── mcp-ragflow          ← 我们的MCP配置（实际文件）
│   └── another-site         ← 其他网站配置
│
└── sites-enabled/            ← 启用的配置（软链接）
    ├── default -> ../sites-available/default
    └── mcp-ragflow -> ../sites-available/mcp-ragflow  ← 指向实际文件的"快捷方式"
```

### 为什么要这样设计？

**优点**：

1. **集中管理** - 所有配置文件在一个地方（sites-available）
2. **灵活启用/禁用** - 只需创建/删除软链接，不删除实际配置
3. **安全** - 误删除软链接不会丢失配置文件
4. **清晰** - 一眼就能看出哪些网站是启用的

**操作示例**：

```bash
# 启用一个网站
sudo ln -s /etc/nginx/sites-available/my-site /etc/nginx/sites-enabled/
sudo nginx -s reload

# 禁用一个网站（临时）
sudo rm /etc/nginx/sites-enabled/my-site
sudo nginx -s reload
# 注意：配置文件还在 sites-available/ 中，没有丢失

# 重新启用
sudo ln -s /etc/nginx/sites-available/my-site /etc/nginx/sites-enabled/
sudo nginx -s reload

# 彻底删除（慎用！）
sudo rm /etc/nginx/sites-available/my-site
sudo rm /etc/nginx/sites-enabled/my-site  # 如果存在
```

### 类比

就像Windows的"快捷方式"：
- 实际程序在 `C:\Program Files\MyApp\app.exe`
- 桌面快捷方式指向这个程序
- 删除快捷方式不会删除程序本身
- 可以创建多个快捷方式指向同一个程序

## 问题2: default 文件要管吗？

### 简短回答

**需要检查！** 可能会有端口冲突。

### 详细说明

#### 场景分析

**场景A: default 监听 80/443 端口 + 使用 `server_name _;`**

```nginx
# /etc/nginx/sites-available/default
server {
    listen 80;
    server_name _;  # ← 这是"捕获所有"域名的通配符
    ...
}
```

**问题**:
- `server_name _;` 是一个特殊值，表示"匹配任何域名"
- 你的 `ddbmcp.xiaofeifei.fun` 请求会被 default 捕获
- MCP配置不会生效

**解决方案**: ✅ **必须禁用 default**

```bash
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -s reload
```

---

**场景B: default 监听 80/443 端口 + 使用特定域名**

```nginx
# /etc/nginx/sites-available/default
server {
    listen 80;
    server_name example.com www.example.com;
    ...
}
```

**结果**: ✅ **没有冲突**
- default 只处理 `example.com` 的请求
- 你的 `ddbmcp.xiaofeifei.fun` 会被 MCP配置处理
- 两者可以共存

**解决方案**: ✅ **不需要操作**

---

**场景C: default 只监听 80 端口，不监听 443**

```nginx
# /etc/nginx/sites-available/default
server {
    listen 80;
    server_name _;
    # 没有 listen 443
}
```

**结果**: ⚠️ **部分冲突**
- HTTP (80端口) 会被 default 捕获
- HTTPS (443端口) 会被 MCP配置处理
- 用户访问 `http://ddbmcp.xiaofeifei.fun` 会看到 default 页面

**解决方案**: ✅ **禁用 default**

```bash
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -s reload
```

### 如何检查

运行检查脚本：

```bash
./check_nginx_config.sh
```

或手动检查：

```bash
# 1. 检查 default 是否启用
ls -l /etc/nginx/sites-enabled/default

# 如果看到类似这样的输出，说明已启用：
# lrwxrwxrwx 1 root root 34 Nov 23 10:00 /etc/nginx/sites-enabled/default -> /etc/nginx/sites-available/default

# 2. 查看 default 配置
cat /etc/nginx/sites-available/default | grep -E "listen|server_name"

# 输出示例1（会冲突）：
# listen 80;
# server_name _;

# 输出示例2（不冲突）：
# listen 80;
# server_name mysite.com;
```

### 推荐操作流程

#### 步骤1: 运行检查

```bash
cd /home/user/ragflow
./check_nginx_config.sh
```

#### 步骤2: 根据检查结果决定

**如果检查脚本显示冲突**：

```bash
# 禁用 default
sudo rm /etc/nginx/sites-enabled/default

# 测试配置
sudo nginx -t

# 重载nginx
sudo systemctl reload nginx
```

**如果检查脚本显示没有冲突**：

```bash
# 保留 default，直接启用 MCP配置
sudo ln -s /etc/nginx/sites-available/mcp-ragflow /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

#### 步骤3: 验证

```bash
# 测试MCP HTTPS端点
curl https://ddbmcp.xiaofeifei.fun/health

# 如果返回200或MCP响应，说明配置正确
# 如果返回404或default页面，说明还有冲突
```

## 端口冲突详解

### Nginx处理请求的优先级

当多个server块监听同一端口时，nginx按以下顺序匹配：

1. **精确匹配** - `server_name example.com;`
2. **通配符开头** - `server_name *.example.com;`
3. **通配符结尾** - `server_name example.*;`
4. **正则表达式** - `server_name ~^www\d+\.example\.com$;`
5. **default_server** - `listen 80 default_server;`
6. **第一个server块** - 如果都不匹配，使用第一个

### 示例：多个配置共存

**正确的配置**：

```nginx
# default - 处理 example.com
server {
    listen 80;
    listen 443 ssl;
    server_name example.com www.example.com;  # ← 特定域名
    ...
}

# mcp-ragflow - 处理 ddbmcp.xiaofeifei.fun
server {
    listen 80;
    listen 443 ssl;
    server_name ddbmcp.xiaofeifei.fun;  # ← 特定域名
    ...
}
```

✅ **结果**: 两者可以共存，各自处理各自的域名

---

**错误的配置**：

```nginx
# default - 捕获所有请求
server {
    listen 80;
    listen 443 ssl;
    server_name _;  # ← 捕获所有
    ...
}

# mcp-ragflow - 永远不会被匹配到！
server {
    listen 80;
    listen 443 ssl;
    server_name ddbmcp.xiaofeifei.fun;
    ...
}
```

❌ **结果**: default 会捕获所有请求，MCP配置不会生效

## 常见问题

### Q1: 如果误删了 sites-available 中的文件怎么办？

A: 配置文件都在你的项目目录中，可以重新复制：

```bash
sudo cp /home/user/ragflow/nginx_mcp_standalone.conf /etc/nginx/sites-available/mcp-ragflow
```

### Q2: 如何查看当前启用了哪些配置？

A:

```bash
# 方法1: 列出软链接
ls -l /etc/nginx/sites-enabled/

# 方法2: 使用检查脚本
./check_nginx_config.sh
```

### Q3: nginx -t 报错 "conflicting server name"

A: 说明有多个server块使用了相同的 `server_name`。检查并禁用冲突的配置。

```bash
# 查找所有使用相同域名的配置
grep -r "server_name ddbmcp.xiaofeifei.fun" /etc/nginx/
```

### Q4: 修改配置后需要重启nginx吗？

A: 通常不需要重启，reload即可：

```bash
# 推荐: reload（平滑重载，不中断现有连接）
sudo systemctl reload nginx

# 或
sudo nginx -s reload

# 不推荐: restart（会中断现有连接）
sudo systemctl restart nginx
```

### Q5: 如何临时禁用MCP配置？

A:

```bash
# 删除软链接（不删除配置文件）
sudo rm /etc/nginx/sites-enabled/mcp-ragflow
sudo nginx -s reload

# 恢复
sudo ln -s /etc/nginx/sites-available/mcp-ragflow /etc/nginx/sites-enabled/
sudo nginx -s reload
```

## 快速命令参考

```bash
# === 软链接操作 ===

# 创建软链接（启用配置）
sudo ln -s /etc/nginx/sites-available/SITE /etc/nginx/sites-enabled/

# 删除软链接（禁用配置）
sudo rm /etc/nginx/sites-enabled/SITE

# 查看软链接指向
ls -l /etc/nginx/sites-enabled/SITE

# === Nginx操作 ===

# 测试配置
sudo nginx -t

# 重载配置（平滑，推荐）
sudo nginx -s reload
# 或
sudo systemctl reload nginx

# 重启nginx（会中断连接）
sudo systemctl restart nginx

# 查看nginx状态
sudo systemctl status nginx

# === 查看日志 ===

# 错误日志
sudo tail -f /var/log/nginx/error.log

# 访问日志
sudo tail -f /var/log/nginx/access.log

# MCP访问日志
sudo tail -f /var/log/nginx/mcp_access.log

# MCP错误日志
sudo tail -f /var/log/nginx/mcp_error.log

# === 检查端口 ===

# 查看80端口
sudo lsof -i :80

# 查看443端口
sudo lsof -i :443

# 查看9382端口（MCP）
sudo lsof -i :9382

# === 配置检查 ===

# 运行配置检查脚本
cd /home/user/ragflow
./check_nginx_config.sh

# 查看所有监听的端口
sudo netstat -tlnp | grep nginx
```

## 推荐工作流程

### 新增网站配置

```bash
# 1. 创建配置文件
sudo vim /etc/nginx/sites-available/my-site

# 2. 测试配置语法
sudo nginx -t

# 3. 启用配置
sudo ln -s /etc/nginx/sites-available/my-site /etc/nginx/sites-enabled/

# 4. 再次测试
sudo nginx -t

# 5. 重载nginx
sudo systemctl reload nginx

# 6. 验证
curl http://your-domain.com
```

### 修改现有配置

```bash
# 1. 编辑配置文件（在 sites-available 中）
sudo vim /etc/nginx/sites-available/my-site

# 2. 测试配置
sudo nginx -t

# 3. 如果测试通过，重载
sudo systemctl reload nginx

# 4. 如果测试失败，修复后重复2-3
```

### 临时禁用网站

```bash
# 1. 删除软链接
sudo rm /etc/nginx/sites-enabled/my-site

# 2. 重载nginx
sudo systemctl reload nginx

# 配置文件仍在 sites-available/ 中，可以随时恢复
```

## 总结

1. **软链接（ln -s）**：
   - 类似Windows快捷方式
   - 用于启用/禁用网站配置
   - 删除链接不会删除实际配置文件

2. **default配置**：
   - 检查是否使用 `server_name _;`
   - 如果冲突，禁用它：`sudo rm /etc/nginx/sites-enabled/default`
   - 如果不冲突，可以共存

3. **最佳实践**：
   - 配置文件放在 `sites-available/`
   - 用软链接启用到 `sites-enabled/`
   - 每次修改后运行 `nginx -t` 测试
   - 使用 `reload` 而不是 `restart`

4. **检查工具**：
   - 运行 `./check_nginx_config.sh` 检查配置
   - 查看端口监听：`sudo lsof -i :端口号`
   - 查看日志：`tail -f /var/log/nginx/error.log`
