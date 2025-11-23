#!/bin/bash
#
# Nginx Configuration Checker for MCP Setup
# Checks for port conflicts and provides guidance
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

echo "============================================"
echo "  Nginx Configuration Checker"
echo "============================================"
echo ""

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    print_error "Nginx is not installed"
    exit 1
fi

print_info "Nginx is installed: $(nginx -v 2>&1)"
echo ""

# Step 1: Check sites-available
print_step "1. Checking /etc/nginx/sites-available/"
echo ""

if [ -d "/etc/nginx/sites-available" ]; then
    print_info "Available site configurations:"
    ls -lh /etc/nginx/sites-available/ | grep -v "^total" | while read line; do
        echo "  $line"
    done
else
    print_warn "Directory /etc/nginx/sites-available/ does not exist"
    print_info "This is normal on some Linux distributions (like CentOS/RHEL)"
fi
echo ""

# Step 2: Check sites-enabled
print_step "2. Checking /etc/nginx/sites-enabled/"
echo ""

if [ -d "/etc/nginx/sites-enabled" ]; then
    print_info "Enabled site configurations:"
    if [ -n "$(ls -A /etc/nginx/sites-enabled/)" ]; then
        ls -lh /etc/nginx/sites-enabled/ | grep -v "^total" | while read line; do
            echo "  $line"
        done
    else
        print_info "  (empty - no sites enabled)"
    fi
else
    print_warn "Directory /etc/nginx/sites-enabled/ does not exist"
fi
echo ""

# Step 3: Check default configuration
print_step "3. Checking default configuration"
echo ""

DEFAULT_AVAILABLE="/etc/nginx/sites-available/default"
DEFAULT_ENABLED="/etc/nginx/sites-enabled/default"

if [ -f "$DEFAULT_AVAILABLE" ]; then
    print_info "Found default configuration at: $DEFAULT_AVAILABLE"

    # Check if default is listening on port 80 or 443
    if grep -q "listen.*80" "$DEFAULT_AVAILABLE"; then
        print_warn "⚠ default is listening on port 80"
        DEFAULT_PORT_80=true
    fi

    if grep -q "listen.*443" "$DEFAULT_AVAILABLE"; then
        print_warn "⚠ default is listening on port 443"
        DEFAULT_PORT_443=true
    fi

    # Check if default is enabled
    if [ -L "$DEFAULT_ENABLED" ]; then
        print_warn "⚠ default configuration is ENABLED (soft link exists)"
        DEFAULT_IS_ENABLED=true
    else
        print_info "✓ default configuration is DISABLED"
        DEFAULT_IS_ENABLED=false
    fi

    # Show server_name from default
    print_info "default server_name:"
    grep "server_name" "$DEFAULT_AVAILABLE" | while read line; do
        echo "  $line"
    done
else
    print_info "No default configuration found"
fi
echo ""

# Step 4: Check MCP configuration
print_step "4. Checking MCP configuration"
echo ""

MCP_AVAILABLE="/etc/nginx/sites-available/mcp-ragflow"
MCP_ENABLED="/etc/nginx/sites-enabled/mcp-ragflow"

if [ -f "$MCP_AVAILABLE" ]; then
    print_info "✓ MCP configuration exists at: $MCP_AVAILABLE"

    if [ -L "$MCP_ENABLED" ]; then
        print_info "✓ MCP configuration is ENABLED"
        MCP_IS_ENABLED=true
    else
        print_warn "⚠ MCP configuration is NOT enabled yet"
        print_info "  Enable it with: sudo ln -s $MCP_AVAILABLE $MCP_ENABLED"
        MCP_IS_ENABLED=false
    fi
else
    print_error "✗ MCP configuration NOT found at: $MCP_AVAILABLE"
    print_info "  Copy it with: sudo cp /home/user/ragflow/nginx_mcp_standalone.conf $MCP_AVAILABLE"
fi
echo ""

# Step 5: Check port conflicts
print_step "5. Checking for port conflicts"
echo ""

# Check who's listening on port 80
print_info "Port 80 listeners:"
sudo lsof -i :80 2>/dev/null | grep LISTEN || echo "  (none)"

# Check who's listening on port 443
print_info "Port 443 listeners:"
sudo lsof -i :443 2>/dev/null | grep LISTEN || echo "  (none)"

# Check who's listening on port 9382
print_info "Port 9382 listeners (MCP):"
sudo lsof -i :9382 2>/dev/null | grep LISTEN || echo "  (none)"
echo ""

# Step 6: Analysis and recommendations
print_step "6. Analysis and Recommendations"
echo ""

NEED_ACTION=false

if [ "$DEFAULT_IS_ENABLED" = true ]; then
    print_warn "⚠ POTENTIAL ISSUE: default configuration is enabled"
    echo ""
    echo "  The default nginx configuration might conflict with your MCP setup."
    echo ""
    echo "  Two scenarios:"
    echo ""
    echo "  Scenario A: default uses catch-all server_name (_)"
    echo "    - This will capture ALL HTTP/HTTPS traffic"
    echo "    - Your MCP domain (ddbmcp.xiaofeifei.fun) will be captured by default"
    echo "    - Solution: DISABLE default"
    echo ""
    echo "  Scenario B: default uses a specific domain"
    echo "    - No conflict if it's a different domain"
    echo "    - Solution: NO ACTION needed"
    echo ""

    # Check if default uses catch-all
    if grep -q "server_name[[:space:]]*_" "$DEFAULT_AVAILABLE" 2>/dev/null; then
        print_error "✗ CONFLICT DETECTED: default uses catch-all server_name (_)"
        echo ""
        echo "  This WILL cause issues. You must disable default:"
        echo ""
        echo "    sudo rm /etc/nginx/sites-enabled/default"
        echo ""
        NEED_ACTION=true
    fi
fi

if [ "$MCP_IS_ENABLED" = false ]; then
    print_warn "⚠ MCP configuration is not enabled yet"
    echo ""
    echo "  Enable it with:"
    echo "    sudo ln -s $MCP_AVAILABLE $MCP_ENABLED"
    echo ""
    NEED_ACTION=true
fi

if [ "$NEED_ACTION" = false ]; then
    print_info "✓ No conflicts detected. Configuration looks good!"
fi

echo ""

# Step 7: Quick commands summary
print_step "7. Quick Commands Summary"
echo ""

print_info "Useful nginx commands:"
echo ""
echo "  # Test nginx configuration"
echo "  sudo nginx -t"
echo ""
echo "  # Reload nginx (apply changes)"
echo "  sudo systemctl reload nginx"
echo ""
echo "  # Restart nginx"
echo "  sudo systemctl restart nginx"
echo ""
echo "  # Enable a site (create soft link)"
echo "  sudo ln -s /etc/nginx/sites-available/SITE_NAME /etc/nginx/sites-enabled/"
echo ""
echo "  # Disable a site (remove soft link, keeps config file)"
echo "  sudo rm /etc/nginx/sites-enabled/SITE_NAME"
echo ""
echo "  # View nginx error log"
echo "  sudo tail -f /var/log/nginx/error.log"
echo ""

# Step 8: Explain soft links
print_step "8. Understanding Soft Links (ln -s)"
echo ""

cat << 'EOF'
Soft links (symbolic links) are like shortcuts in Windows:

  Source File                    Soft Link
  ┌─────────────────┐            ┌─────────────────┐
  │ sites-available │            │ sites-enabled   │
  │                 │            │                 │
  │ mcp-ragflow     │ <────────┐ │ mcp-ragflow ────┼──> points to source
  └─────────────────┘          │ └─────────────────┘
                               │
                               └── soft link

Benefits:
  • Easy to enable/disable sites (just create/delete links)
  • Keep original config safe in sites-available/
  • Multiple links can point to the same file

Commands:
  • Create link:  ln -s /path/to/source /path/to/link
  • Remove link:  rm /path/to/link  (doesn't delete source!)
  • Check link:   ls -l /path/to/link

Example for MCP:
  • Source: /etc/nginx/sites-available/mcp-ragflow  ← actual config file
  • Link:   /etc/nginx/sites-enabled/mcp-ragflow    ← shortcut to enable it
  • Nginx only loads configs from sites-enabled/

To disable MCP (temporarily):
  sudo rm /etc/nginx/sites-enabled/mcp-ragflow
  sudo nginx -s reload
  # Config file still exists in sites-available/

To re-enable MCP:
  sudo ln -s /etc/nginx/sites-available/mcp-ragflow /etc/nginx/sites-enabled/
  sudo nginx -s reload
EOF

echo ""
echo "============================================"
print_info "Configuration check completed!"
echo "============================================"
