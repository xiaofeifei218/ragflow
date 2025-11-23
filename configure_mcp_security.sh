#!/bin/bash
#
# MCP Security Configuration Helper
# Helps choose and configure secure MCP deployment
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_title() {
    echo -e "${BLUE}$1${NC}"
}

echo "============================================"
echo "  MCP Security Configuration"
echo "============================================"
echo ""

print_warn "⚠️  SECURITY NOTICE"
echo ""
echo "Self-host mode has security implications:"
echo "  - Anyone who can access the MCP server can access your data"
echo "  - No authentication required from clients"
echo "  - API key is bound to the MCP server, not individual requests"
echo ""

print_title "Choose your deployment scenario:"
echo ""
echo "1) Same machine (Claude Desktop on same host as MCP)"
echo "   → Most secure, MCP only listens on localhost"
echo ""
echo "2) Local network (Claude Desktop on another machine in LAN)"
echo "   → Add firewall rules to restrict access"
echo ""
echo "3) Public/Internet (Claude Desktop anywhere)"
echo "   → Use HTTPS + nginx + optional Basic Auth"
echo ""
echo "4) Multi-user (Team/Organization)"
echo "   → Switch to Host mode, each user has API key"
echo ""

read -p "Select option (1-4): " OPTION

case $OPTION in
    1)
        print_title "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_title "  Option 1: Same Machine (Localhost)"
        print_title "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        cat << 'EOF'
Configuration:
  - MCP server: --mcp-host=127.0.0.1
  - Claude Desktop: http://127.0.0.1:9382/mcp

Docker compose configuration:
```yaml
command:
  - --enable-mcpserver
  - --mcp-host=127.0.0.1  # ← localhost only
  - --mcp-port=9382
  - --mcp-mode=self-host
  - --mcp-host-api-key=YOUR-API-KEY
```

Claude Desktop config (claude_desktop_config.json):
```json
{
  "mcpServers": {
    "ragflow": {
      "command": "curl",
      "args": ["-X", "POST", "http://127.0.0.1:9382/mcp"]
    }
  }
}
```

Security: ✅ Excellent (only accessible from localhost)
EOF
        ;;

    2)
        print_title "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_title "  Option 2: Local Network"
        print_title "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        echo "Enter the IP of the machine running Claude Desktop:"
        read -p "Claude Desktop IP: " CLAUDE_IP

        cat << EOF

Configuration:
  - MCP server: --mcp-host=0.0.0.0
  - Firewall: Allow only $CLAUDE_IP
  - Claude Desktop: http://YOUR_SERVER_IP:9382/mcp

Docker compose configuration:
\`\`\`yaml
command:
  - --enable-mcpserver
  - --mcp-host=0.0.0.0  # ← listen on network
  - --mcp-port=9382
  - --mcp-mode=self-host
  - --mcp-host-api-key=YOUR-API-KEY
\`\`\`

Firewall setup:
\`\`\`bash
# Ubuntu/Debian
sudo ufw allow from $CLAUDE_IP to any port 9382 proto tcp
sudo ufw enable

# Or allow entire subnet (e.g., 192.168.1.0/24)
sudo ufw allow from 192.168.1.0/24 to any port 9382 proto tcp
\`\`\`

Claude Desktop config (claude_desktop_config.json):
\`\`\`json
{
  "mcpServers": {
    "ragflow": {
      "command": "curl",
      "args": ["-X", "POST", "http://YOUR_SERVER_IP:9382/mcp"]
    }
  }
}
\`\`\`

Security: ✅ Good (firewall-protected)
EOF
        ;;

    3)
        print_title "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_title "  Option 3: Public Internet"
        print_title "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        cat << 'EOF'
Configuration:
  - MCP server: --mcp-host=127.0.0.1 (behind nginx)
  - Nginx: HTTPS reverse proxy with optional Basic Auth
  - Claude Desktop: https://your-domain.com/mcp

1. MCP Server Configuration (localhost only):
```yaml
command:
  - --enable-mcpserver
  - --mcp-host=127.0.0.1  # ← localhost, nginx will proxy
  - --mcp-port=9382
  - --mcp-mode=self-host
  - --mcp-host-api-key=YOUR-API-KEY
```

2. Nginx Configuration with Basic Auth:
```nginx
server {
    listen 443 ssl;
    server_name ddbmcp.xiaofeifei.fun;

    ssl_certificate /path/to/fullchain.cer;
    ssl_certificate_key /path/to/privkey.key;

    # Add Basic Authentication
    auth_basic "MCP Access";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location /mcp {
        proxy_pass http://127.0.0.1:9382;
        proxy_set_header Host $host;
        proxy_buffering off;
    }
}
```

3. Create password file:
```bash
sudo htpasswd -c /etc/nginx/.htpasswd mcp_user
# Enter password when prompted
```

4. Claude Desktop config:
```json
{
  "mcpServers": {
    "ragflow": {
      "command": "curl",
      "args": [
        "-u", "mcp_user:your_password",
        "-X", "POST",
        "https://ddbmcp.xiaofeifei.fun/mcp"
      ]
    }
  }
}
```

Security: ⚠️ Moderate (HTTPS + Basic Auth recommended)

See nginx_mcp_standalone.conf for full nginx configuration.
EOF
        ;;

    4)
        print_title "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_title "  Option 4: Multi-User (Host Mode)"
        print_title "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        cat << 'EOF'
Configuration:
  - Mode: Host (each client provides their own API key)
  - MCP server: No API key at startup
  - Claude Desktop: Must include API key in each request

Docker compose configuration:
```yaml
command:
  - --enable-mcpserver
  - --mcp-host=0.0.0.0
  - --mcp-port=9382
  - --mcp-mode=host  # ← Host mode
  # NO --mcp-host-api-key !
  - --no-transport-streamable-http-enabled  # Host mode requires SSE
```

Note: Host mode currently only supports SSE transport, not streamable-http.

Claude Desktop config for User A:
```json
{
  "mcpServers": {
    "ragflow": {
      "command": "curl",
      "args": [
        "-H", "Authorization: Bearer ragflow-user-a-api-key",
        "-N",
        "-H", "Accept: text/event-stream",
        "http://YOUR_IP:9382/sse"
      ]
    }
  }
}
```

Claude Desktop config for User B:
```json
{
  "mcpServers": {
    "ragflow": {
      "command": "curl",
      "args": [
        "-H", "Authorization: Bearer ragflow-user-b-api-key",
        "-N",
        "-H", "Accept: text/event-stream",
        "http://YOUR_IP:9382/sse"
      ]
    }
  }
}
```

Each user gets their own data based on their API key.

Security: ✅ Excellent (per-request authentication)

Combine with HTTPS for production deployment.
EOF
        ;;

    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

echo ""
echo "============================================"
print_info "Configuration guidance completed!"
echo "============================================"
echo ""
print_warn "Remember:"
echo "  • Never expose MCP directly to internet without protection"
echo "  • Use HTTPS for public deployments"
echo "  • Consider firewall rules even in private networks"
echo "  • Regular security audits recommended"
echo ""
