#!/bin/bash
#
# RAGFlow Docker MCP Testing Script
# Tests MCP server running in Docker with HTTPS reverse proxy
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MCP_DOMAIN="ddbmcp.xiaofeifei.fun"
LOCAL_MCP="http://127.0.0.1:9382"
RAGFLOW_URL="http://127.0.0.1:9380"
DOCKER_CONTAINER="ragflow-server"

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

echo "============================================"
echo "  RAGFlow Docker MCP Test Suite"
echo "============================================"
echo ""

# Test 1: Docker Container Running
print_test "1. Checking Docker container..."
if docker ps --format '{{.Names}}' | grep -q "ragflow"; then
    CONTAINER_NAME=$(docker ps --format '{{.Names}}' | grep ragflow | head -n 1)
    print_pass "Docker container is running: $CONTAINER_NAME"
    print_info "  Container ID: $(docker ps --format '{{.ID}}' | head -n 1)"
else
    print_fail "Docker container is not running"
    print_info "  Start with: cd /home/user/ragflow/docker && docker compose up -d"
    exit 1
fi
echo ""

# Test 2: MCP Configuration in Container
print_test "2. Checking MCP configuration in container..."
MCP_LOGS=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -i "MCP" | tail -n 10)
if echo "$MCP_LOGS" | grep -q "MCP host"; then
    print_pass "MCP server is configured"
    echo "$MCP_LOGS" | while read line; do
        print_info "  $line"
    done

    # Check if listening on 0.0.0.0
    if echo "$MCP_LOGS" | grep -q "MCP host: 0.0.0.0"; then
        print_pass "✓ MCP is listening on 0.0.0.0 (accessible from host)"
    elif echo "$MCP_LOGS" | grep -q "MCP host: 127.0.0.1"; then
        print_fail "✗ MCP is listening on 127.0.0.1 (NOT accessible from host)"
        print_info "  Fix with: ./fix_docker_mcp.sh"
    fi
else
    print_fail "MCP server not found in container logs"
    print_info "  Check if MCP is enabled in docker-compose.yml"
fi
echo ""

# Test 3: Port Mapping
print_test "3. Checking Docker port mapping..."
PORT_MAPPING=$(docker port "$CONTAINER_NAME" 9382 2>/dev/null)
if [ -n "$PORT_MAPPING" ]; then
    print_pass "Port 9382 is mapped: $PORT_MAPPING"
else
    print_fail "Port 9382 is NOT mapped"
    print_info "  Uncomment port mapping in docker-compose.yml: - \${SVR_MCP_PORT}:9382"
    print_info "  Then restart: docker compose down && docker compose up -d"
fi
echo ""

# Test 4: RAGFlow Server
print_test "4. Testing RAGFlow server connectivity..."
if curl -s -f "$RAGFLOW_URL/api/v1/system/status" > /dev/null 2>&1; then
    print_pass "RAGFlow server is accessible"
else
    print_fail "RAGFlow server is not accessible at $RAGFLOW_URL"
fi
echo ""

# Test 5: Local MCP Server (from host)
print_test "5. Testing MCP server from host machine..."
if curl -s -f "$LOCAL_MCP/health" -m 5 > /dev/null 2>&1; then
    print_pass "MCP server is accessible from host at $LOCAL_MCP"
else
    print_fail "MCP server is NOT accessible from host"
    print_info "  Possible issues:"
    print_info "    1. MCP listening on 127.0.0.1 in container (should be 0.0.0.0)"
    print_info "    2. Port mapping not configured"
    print_info "    3. MCP server not started"
    print_info "  Run: ./fix_docker_mcp.sh"
fi
echo ""

# Test 6: MCP Inside Container
print_test "6. Testing MCP server inside container..."
if docker exec "$CONTAINER_NAME" curl -s -f http://localhost:9382/health -m 5 > /dev/null 2>&1; then
    print_pass "MCP server is running inside container"
else
    print_fail "MCP server is not responding inside container"
    print_info "  Check container logs: docker logs $CONTAINER_NAME | grep -i mcp"
fi
echo ""

# Test 7: HTTPS Endpoint
print_test "7. Testing HTTPS endpoint..."
if curl -s -f "https://$MCP_DOMAIN/health" -m 10 > /dev/null 2>&1; then
    print_pass "HTTPS endpoint is accessible"
else
    print_fail "HTTPS endpoint is not accessible at https://$MCP_DOMAIN"
    print_info "  Check nginx configuration and DNS settings"
fi
echo ""

# Test 8: SSL Certificate
print_test "8. Testing SSL certificate..."
ssl_output=$(echo | openssl s_client -servername "$MCP_DOMAIN" -connect "$MCP_DOMAIN:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
if [ $? -eq 0 ]; then
    print_pass "SSL certificate is valid"
    print_info "  $ssl_output"
else
    print_fail "SSL certificate check failed"
fi
echo ""

# Test 9: HTTP to HTTPS Redirect
print_test "9. Testing HTTP to HTTPS redirect..."
redirect_response=$(curl -s -o /dev/null -w "%{http_code}" "http://$MCP_DOMAIN/" -m 5)
if [ "$redirect_response" = "301" ] || [ "$redirect_response" = "302" ]; then
    print_pass "HTTP to HTTPS redirect is working (Status: $redirect_response)"
else
    print_fail "HTTP to HTTPS redirect is not working (Status: $redirect_response)"
fi
echo ""

# Test 10: Nginx Status
print_test "10. Testing nginx service..."
if systemctl is-active --quiet nginx 2>/dev/null; then
    print_pass "Nginx is running"
elif command -v nginx &> /dev/null; then
    print_pass "Nginx is installed"
    print_warn "Cannot check if nginx is running (no systemctl access)"
else
    print_fail "Nginx is not installed"
fi
echo ""

# Summary
echo "============================================"
echo "  Test Summary"
echo "============================================"
echo ""

print_info "Docker Information:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E "NAME|ragflow" || true
echo ""

print_info "Quick troubleshooting commands:"
echo ""
echo "  # View MCP logs from container"
echo "  docker logs $CONTAINER_NAME | grep -i mcp"
echo ""
echo "  # View recent container logs"
echo "  docker logs --tail 50 $CONTAINER_NAME"
echo ""
echo "  # Check MCP inside container"
echo "  docker exec $CONTAINER_NAME curl -v http://localhost:9382/health"
echo ""
echo "  # Check port binding"
echo "  docker port $CONTAINER_NAME"
echo ""
echo "  # Restart container"
echo "  cd /home/user/ragflow/docker && docker compose restart"
echo ""

print_info "Configuration files:"
echo "  - Docker Compose: /home/user/ragflow/docker/docker-compose.yml"
echo "  - Nginx Config: /etc/nginx/sites-available/mcp-ragflow"
echo "  - Fix Script: /home/user/ragflow/fix_docker_mcp.sh"
echo ""

print_info "Detailed guides:"
echo "  - Docker Setup: /home/user/ragflow/DOCKER_MCP_SETUP.md"
echo "  - General Setup: /home/user/ragflow/MCP_SETUP_README.md"
echo ""
