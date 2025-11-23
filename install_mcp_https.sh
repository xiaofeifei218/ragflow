#!/bin/bash
#
# RAGFlow MCP Server HTTPS Setup - Quick Installation Script
# This script automates the deployment of MCP server with nginx HTTPS reverse proxy
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MCP_DOMAIN="ddbmcp.xiaofeifei.fun"
CERT_DIR="/home/xiaofeifei/.acme.sh/xiaofeifei.fun_ecc"
NGINX_CONF_NAME="mcp-ragflow"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Helper functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

# Step 1: Pre-flight checks
print_info "Starting RAGFlow MCP Server HTTPS setup..."
echo ""

print_info "Step 1: Checking prerequisites..."

# Check if nginx is installed
check_command nginx

# Check if uv is installed
check_command uv

# Check if RAGFlow is accessible
if curl -s -f http://127.0.0.1:9380/api/v1/system/status > /dev/null 2>&1; then
    print_info "✓ RAGFlow server is running"
else
    print_warn "⚠ RAGFlow server might not be running at http://127.0.0.1:9380"
    print_warn "  Please ensure RAGFlow is started before using MCP server"
fi

# Check if SSL certificates exist
if [ -f "$CERT_DIR/fullchain.cer" ] && [ -f "$CERT_DIR/xiaofeifei.fun.key" ]; then
    print_info "✓ SSL certificates found"
else
    print_error "SSL certificates not found at $CERT_DIR"
    print_error "Expected files:"
    print_error "  - $CERT_DIR/fullchain.cer"
    print_error "  - $CERT_DIR/xiaofeifei.fun.key"
    exit 1
fi

# Check API key
if [ -z "$RAGFLOW_API_KEY" ] || [ "$RAGFLOW_API_KEY" = "ragflow-xxxxx" ]; then
    print_error "RAGFLOW_API_KEY environment variable is not set"
    print_error "Please set it: export RAGFLOW_API_KEY=ragflow-your-actual-key"
    exit 1
fi
print_info "✓ API key is set"

echo ""

# Step 2: Install nginx configuration
print_info "Step 2: Installing nginx configuration..."

if [ ! -f "$SCRIPT_DIR/nginx_mcp_https.conf" ]; then
    print_error "nginx_mcp_https.conf not found in $SCRIPT_DIR"
    exit 1
fi

# Copy nginx config
sudo cp "$SCRIPT_DIR/nginx_mcp_https.conf" "/etc/nginx/sites-available/$NGINX_CONF_NAME"
print_info "✓ Copied nginx configuration to /etc/nginx/sites-available/$NGINX_CONF_NAME"

# Create symlink if it doesn't exist
if [ ! -L "/etc/nginx/sites-enabled/$NGINX_CONF_NAME" ]; then
    sudo ln -s "/etc/nginx/sites-available/$NGINX_CONF_NAME" "/etc/nginx/sites-enabled/$NGINX_CONF_NAME"
    print_info "✓ Enabled nginx configuration"
else
    print_info "✓ Nginx configuration already enabled"
fi

# Test nginx configuration
if sudo nginx -t > /dev/null 2>&1; then
    print_info "✓ Nginx configuration is valid"
else
    print_error "Nginx configuration test failed"
    sudo nginx -t
    exit 1
fi

# Reload nginx
sudo systemctl reload nginx
print_info "✓ Nginx reloaded"

echo ""

# Step 3: Set up MCP server startup script
print_info "Step 3: Setting up MCP server startup script..."

if [ ! -f "$SCRIPT_DIR/start_mcp_server.sh" ]; then
    print_error "start_mcp_server.sh not found in $SCRIPT_DIR"
    exit 1
fi

chmod +x "$SCRIPT_DIR/start_mcp_server.sh"
print_info "✓ Made start_mcp_server.sh executable"

echo ""

# Step 4: Create systemd service (optional)
print_info "Step 4: Do you want to create a systemd service for MCP server? (y/n)"
read -r CREATE_SERVICE

if [ "$CREATE_SERVICE" = "y" ] || [ "$CREATE_SERVICE" = "Y" ]; then
    print_info "Creating systemd service..."

    # Get current user
    CURRENT_USER=$(whoami)

    # Create systemd service file
    sudo tee /etc/systemd/system/ragflow-mcp.service > /dev/null <<EOF
[Unit]
Description=RAGFlow MCP Server
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$SCRIPT_DIR
Environment="RAGFLOW_API_KEY=$RAGFLOW_API_KEY"
ExecStart=$SCRIPT_DIR/start_mcp_server.sh
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    print_info "✓ Created systemd service file"

    # Reload systemd
    sudo systemctl daemon-reload
    print_info "✓ Reloaded systemd"

    # Enable service
    sudo systemctl enable ragflow-mcp
    print_info "✓ Enabled ragflow-mcp service"

    # Start service
    print_info "Starting MCP server service..."
    sudo systemctl start ragflow-mcp

    sleep 2

    # Check status
    if sudo systemctl is-active --quiet ragflow-mcp; then
        print_info "✓ MCP server service is running"
    else
        print_error "Failed to start MCP server service"
        sudo systemctl status ragflow-mcp
        exit 1
    fi

    echo ""
    print_info "Service commands:"
    print_info "  Start:   sudo systemctl start ragflow-mcp"
    print_info "  Stop:    sudo systemctl stop ragflow-mcp"
    print_info "  Restart: sudo systemctl restart ragflow-mcp"
    print_info "  Status:  sudo systemctl status ragflow-mcp"
    print_info "  Logs:    sudo journalctl -u ragflow-mcp -f"
else
    print_info "Skipping systemd service creation"
    print_info "You can start MCP server manually:"
    print_info "  cd $SCRIPT_DIR && ./start_mcp_server.sh"
fi

echo ""

# Step 5: Verification
print_info "Step 5: Verifying deployment..."

# Wait a bit for service to start
sleep 3

# Test local MCP server
if curl -s -f http://127.0.0.1:9382/health > /dev/null 2>&1; then
    print_info "✓ MCP server is responding locally"
else
    print_warn "⚠ MCP server might not be started yet"
fi

# Test HTTPS endpoint
if curl -s -f https://$MCP_DOMAIN/health > /dev/null 2>&1; then
    print_info "✓ HTTPS endpoint is accessible"
else
    print_warn "⚠ HTTPS endpoint might not be accessible yet"
    print_warn "  This could be due to DNS not being resolved or firewall rules"
fi

echo ""
echo "============================================"
print_info "MCP Server HTTPS setup completed!"
echo "============================================"
echo ""
print_info "MCP Server URL: https://$MCP_DOMAIN"
print_info "  - SSE endpoint: https://$MCP_DOMAIN/sse"
print_info "  - MCP endpoint: https://$MCP_DOMAIN/mcp (recommended)"
echo ""
print_info "Next steps:"
print_info "1. Test the server:"
print_info "   curl https://$MCP_DOMAIN/health"
echo ""
print_info "2. Configure your MCP client to use:"
print_info "   URL: https://$MCP_DOMAIN/mcp"
print_info "   Transport: streamable-http"
echo ""
print_info "3. Monitor logs:"
if [ "$CREATE_SERVICE" = "y" ] || [ "$CREATE_SERVICE" = "Y" ]; then
    print_info "   sudo journalctl -u ragflow-mcp -f"
else
    print_info "   Check the terminal where start_mcp_server.sh is running"
fi
echo ""
print_info "For detailed documentation, see: MCP_HTTPS_DEPLOYMENT.md"
echo ""
