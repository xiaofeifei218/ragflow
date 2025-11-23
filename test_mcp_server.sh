#!/bin/bash
#
# RAGFlow MCP Server Testing Script
# Tests the MCP server deployment and connectivity
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

run_test() {
    local test_name="$1"
    local test_cmd="$2"

    print_test "$test_name"

    if eval "$test_cmd" > /dev/null 2>&1; then
        print_pass "$test_name"
        return 0
    else
        print_fail "$test_name"
        return 1
    fi
}

echo "============================================"
echo "  RAGFlow MCP Server Test Suite"
echo "============================================"
echo ""

# Test 1: RAGFlow Server
print_test "1. Testing RAGFlow server connectivity..."
if curl -s -f "$RAGFLOW_URL/api/v1/system/status" > /dev/null 2>&1; then
    print_pass "RAGFlow server is running"
    ragflow_version=$(curl -s "$RAGFLOW_URL/api/v1/system/status" | grep -o '"version":"[^"]*"' || echo "unknown")
    print_info "  $ragflow_version"
else
    print_fail "RAGFlow server is not accessible at $RAGFLOW_URL"
    print_info "  Please start RAGFlow server first"
fi
echo ""

# Test 2: Local MCP Server
print_test "2. Testing local MCP server..."
if curl -s -f "$LOCAL_MCP/health" > /dev/null 2>&1; then
    print_pass "MCP server is running locally"
else
    print_fail "MCP server is not accessible at $LOCAL_MCP"
    print_info "  Please start MCP server: ./start_mcp_server.sh"
fi
echo ""

# Test 3: HTTPS Endpoint
print_test "3. Testing HTTPS endpoint..."
if curl -s -f "https://$MCP_DOMAIN/health" > /dev/null 2>&1; then
    print_pass "HTTPS endpoint is accessible"
else
    print_fail "HTTPS endpoint is not accessible at https://$MCP_DOMAIN"
    print_info "  Check nginx configuration and DNS settings"
fi
echo ""

# Test 4: SSL Certificate
print_test "4. Testing SSL certificate..."
ssl_output=$(echo | openssl s_client -servername "$MCP_DOMAIN" -connect "$MCP_DOMAIN:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
if [ $? -eq 0 ]; then
    print_pass "SSL certificate is valid"
    print_info "  $ssl_output"
else
    print_fail "SSL certificate check failed"
fi
echo ""

# Test 5: HTTP to HTTPS Redirect
print_test "5. Testing HTTP to HTTPS redirect..."
redirect_response=$(curl -s -o /dev/null -w "%{http_code}" "http://$MCP_DOMAIN/")
if [ "$redirect_response" = "301" ] || [ "$redirect_response" = "302" ]; then
    print_pass "HTTP to HTTPS redirect is working (Status: $redirect_response)"
else
    print_fail "HTTP to HTTPS redirect is not working (Status: $redirect_response)"
fi
echo ""

# Test 6: SSE Endpoint
print_test "6. Testing SSE endpoint..."
if curl -s -f "https://$MCP_DOMAIN/sse" -H "Content-Type: application/json" > /dev/null 2>&1; then
    print_pass "SSE endpoint is accessible"
else
    print_fail "SSE endpoint returned an error"
    print_info "  This might be expected if no valid request was made"
fi
echo ""

# Test 7: MCP Endpoint
print_test "7. Testing MCP endpoint (streamable HTTP)..."
if curl -s -f "https://$MCP_DOMAIN/mcp" -H "Content-Type: application/json" > /dev/null 2>&1; then
    print_pass "MCP endpoint is accessible"
else
    print_fail "MCP endpoint returned an error"
    print_info "  This might be expected if no valid request was made"
fi
echo ""

# Test 8: DNS Resolution
print_test "8. Testing DNS resolution..."
dns_ip=$(dig +short "$MCP_DOMAIN" | head -n 1)
if [ -n "$dns_ip" ]; then
    print_pass "DNS resolves to: $dns_ip"
else
    print_fail "DNS resolution failed for $MCP_DOMAIN"
fi
echo ""

# Test 9: Port Connectivity
print_test "9. Testing port 443 connectivity..."
if timeout 3 bash -c "echo > /dev/tcp/$MCP_DOMAIN/443" 2>/dev/null; then
    print_pass "Port 443 is open and accessible"
else
    print_fail "Cannot connect to port 443"
    print_info "  Check firewall rules"
fi
echo ""

# Test 10: Nginx Status
print_test "10. Testing nginx service..."
if systemctl is-active --quiet nginx; then
    print_pass "Nginx is running"
    nginx_version=$(nginx -v 2>&1 | grep -o 'nginx/[^ ]*' || echo "unknown")
    print_info "  Version: $nginx_version"
else
    print_fail "Nginx is not running"
    print_info "  Start nginx: sudo systemctl start nginx"
fi
echo ""

# Test 11: MCP Service (if systemd service exists)
if systemctl list-unit-files | grep -q ragflow-mcp; then
    print_test "11. Testing MCP systemd service..."
    if systemctl is-active --quiet ragflow-mcp; then
        print_pass "MCP service is running"
        print_info "  Status: $(systemctl is-active ragflow-mcp)"
    else
        print_fail "MCP service is not running"
        print_info "  Start service: sudo systemctl start ragflow-mcp"
    fi
    echo ""
fi

# Summary
echo "============================================"
echo "  Test Summary"
echo "============================================"
echo ""

# Detailed connectivity test
print_info "Detailed connectivity test:"
echo ""

print_info "Testing local MCP server..."
curl -v "$LOCAL_MCP/health" 2>&1 | head -n 10
echo ""

print_info "Testing HTTPS endpoint..."
curl -v "https://$MCP_DOMAIN/health" 2>&1 | head -n 15
echo ""

print_info "For detailed logs, check:"
if systemctl list-unit-files | grep -q ragflow-mcp; then
    echo "  - MCP Server: sudo journalctl -u ragflow-mcp -f"
fi
echo "  - Nginx Access: sudo tail -f /var/log/nginx/mcp_access.log"
echo "  - Nginx Error: sudo tail -f /var/log/nginx/mcp_error.log"
echo ""

print_info "Configuration files:"
echo "  - Nginx: /etc/nginx/sites-available/mcp-ragflow"
echo "  - MCP Script: $(pwd)/start_mcp_server.sh"
if systemctl list-unit-files | grep -q ragflow-mcp; then
    echo "  - Systemd Service: /etc/systemd/system/ragflow-mcp.service"
fi
echo ""
