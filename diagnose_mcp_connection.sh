#!/bin/bash
#
# MCP Connection Diagnostic Tool
# Helps diagnose connection issues between Claude Desktop and MCP server
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

echo "============================================"
echo "  MCP Connection Diagnostics"
echo "============================================"
echo ""

# Test 1: Check if MCP server is running
print_test "1. Checking if MCP server is running..."

MCP_LOCAL_TEST=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:9382/mcp 2>/dev/null)

if [ "$MCP_LOCAL_TEST" = "000" ]; then
    print_error "MCP server is NOT running (connection refused)"
    echo "  → Start MCP server first"
    echo ""
    exit 1
elif [ "$MCP_LOCAL_TEST" = "404" ]; then
    print_warn "Server running but /mcp endpoint not found"
    echo "  → Try /sse endpoint instead"
elif [ "$MCP_LOCAL_TEST" = "200" ] || [ "$MCP_LOCAL_TEST" = "400" ] || [ "$MCP_LOCAL_TEST" = "405" ]; then
    print_info "MCP server is running and responding"
else
    print_warn "Unexpected response code: $MCP_LOCAL_TEST"
fi
echo ""

# Test 2: Check available endpoints
print_test "2. Testing available endpoints..."
echo ""

echo "  Testing /mcp endpoint..."
MCP_RESPONSE=$(curl -s -X POST http://localhost:9382/mcp 2>&1)
MCP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:9382/mcp 2>/dev/null)
echo "    Response code: $MCP_CODE"
echo "    Response preview: ${MCP_RESPONSE:0:100}"
echo ""

echo "  Testing /sse endpoint..."
SSE_CODE=$(timeout 2 curl -s -o /dev/null -w "%{http_code}" -N http://localhost:9382/sse 2>/dev/null || echo "timeout")
echo "    Response code: $SSE_CODE"
echo ""

# Test 3: Check Docker container
print_test "3. Checking Docker container..."

if command -v docker &> /dev/null; then
    CONTAINER=$(docker ps --filter "name=ragflow" --format "{{.Names}}" 2>/dev/null | head -1)

    if [ -n "$CONTAINER" ]; then
        print_info "Docker container running: $CONTAINER"

        echo ""
        echo "  Container logs (last 20 MCP-related lines):"
        echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        docker logs "$CONTAINER" 2>&1 | grep -i "mcp" | tail -20
        echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        print_error "No RAGFlow Docker container found"
        echo "  → Start Docker containers first"
    fi
else
    print_warn "Docker command not available from this shell"
fi
echo ""

# Test 4: Check port binding
print_test "4. Checking port 9382..."

PORT_CHECK=$(sudo lsof -i :9382 2>/dev/null || netstat -tlnp 2>/dev/null | grep 9382 || ss -tlnp 2>/dev/null | grep 9382)

if [ -n "$PORT_CHECK" ]; then
    print_info "Port 9382 is in use:"
    echo "$PORT_CHECK"
else
    print_error "Port 9382 is not listening"
    echo "  → MCP server might not be started"
fi
echo ""

# Test 5: Network accessibility
print_test "5. Testing network accessibility..."

# Get local IPs
LOCAL_IPS=$(hostname -I 2>/dev/null || ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d'/' -f1)

echo "  Local IP addresses:"
for IP in $LOCAL_IPS; do
    echo "    - $IP"

    # Test each IP
    IP_TEST=$(timeout 2 curl -s -o /dev/null -w "%{http_code}" -X POST "http://$IP:9382/mcp" 2>/dev/null || echo "timeout")
    if [ "$IP_TEST" = "000" ] || [ "$IP_TEST" = "timeout" ]; then
        echo "      ✗ Not accessible from $IP"
    else
        echo "      ✓ Accessible from $IP (code: $IP_TEST)"
    fi
done
echo ""

# Test 6: Firewall check
print_test "6. Checking firewall status..."

if command -v ufw &> /dev/null; then
    UFW_STATUS=$(sudo ufw status 2>/dev/null | grep "9382")
    if [ -n "$UFW_STATUS" ]; then
        print_info "Firewall rules for port 9382:"
        echo "$UFW_STATUS"
    else
        print_warn "No firewall rules found for port 9382"
        echo "  → If accessing from another machine, you may need to allow the port"
    fi
else
    print_warn "ufw not available, cannot check firewall"
fi
echo ""

# Test 7: MCP configuration check
print_test "7. Checking MCP configuration..."

COMPOSE_FILE="/home/user/ragflow/docker/docker-compose.yml"
if [ -f "$COMPOSE_FILE" ]; then
    if grep -q "^\s*#.*enable-mcpserver" "$COMPOSE_FILE"; then
        print_error "MCP configuration is commented out in docker-compose.yml"
        echo "  → Run: ./enable_mcp_in_docker.sh"
    elif grep -q "enable-mcpserver" "$COMPOSE_FILE"; then
        print_info "MCP is enabled in docker-compose.yml"

        # Check host binding
        MCP_HOST=$(grep "mcp-host=" "$COMPOSE_FILE" | grep -v "^#" | sed 's/.*mcp-host=\([^ ]*\).*/\1/')
        echo "  MCP host: $MCP_HOST"

        if [ "$MCP_HOST" = "127.0.0.1" ]; then
            print_warn "MCP is only listening on localhost (127.0.0.1)"
            echo "  → To access from other machines, change to 0.0.0.0"
        elif [ "$MCP_HOST" = "0.0.0.0" ]; then
            print_info "MCP is listening on all interfaces (0.0.0.0)"
        fi
    else
        print_warn "Cannot find MCP configuration in docker-compose.yml"
    fi
else
    print_error "docker-compose.yml not found"
fi
echo ""

# Test 8: Provide recommendations
echo "============================================"
echo "  Recommendations"
echo "============================================"
echo ""

if [ "$MCP_LOCAL_TEST" = "000" ]; then
    cat << 'EOF'
❌ CRITICAL: MCP server is not running

Fix steps:
1. Enable MCP in docker-compose.yml:
   ./enable_mcp_in_docker.sh

2. Restart Docker:
   cd docker
   docker compose down
   docker compose up -d

3. Verify:
   docker logs ragflow-server | grep MCP
EOF
elif [ "$MCP_CODE" = "404" ] || [ "$MCP_CODE" = "405" ]; then
    cat << 'EOF'
⚠️  MCP server is running but endpoint may be wrong

Try these URLs in Claude Desktop:
  • http://127.0.0.1:9382/sse  (SSE transport)
  • http://127.0.0.1:9382/mcp  (Streamable HTTP)

SSE is more stable with older MCP versions.
EOF
else
    cat << 'EOF'
✅ MCP server appears to be working

For Claude Desktop, use:
  • Local: http://127.0.0.1:9382/mcp
  • Network: http://YOUR_LOCAL_IP:9382/mcp

If still having issues:
1. Check Claude Desktop logs
2. Try SSE endpoint: http://127.0.0.1:9382/sse
3. Ensure no OAuth fields are filled in Claude Desktop
4. Restart Claude Desktop completely
EOF
fi

echo ""
echo "============================================"
echo "  Quick Test Commands"
echo "============================================"
echo ""

cat << 'EOF'
# Test local MCP endpoint
curl -v -X POST http://127.0.0.1:9382/mcp

# Test SSE endpoint
curl -N http://127.0.0.1:9382/sse

# View MCP logs
docker logs ragflow-server 2>&1 | grep -i mcp

# Check what's listening on 9382
sudo lsof -i :9382

# Restart MCP
cd docker && docker compose restart
EOF

echo ""
