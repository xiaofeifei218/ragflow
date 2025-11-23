#!/bin/bash
#
# RAGFlow Docker MCP Configuration Fix Script
# This script automatically fixes docker-compose.yml for MCP HTTPS access
#

set -e

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

DOCKER_DIR="/home/user/ragflow/docker"
COMPOSE_FILE="$DOCKER_DIR/docker-compose.yml"

echo "============================================"
echo "  RAGFlow Docker MCP Configuration Fixer"
echo "============================================"
echo ""

# Check if docker-compose.yml exists
if [ ! -f "$COMPOSE_FILE" ]; then
    print_error "docker-compose.yml not found at $COMPOSE_FILE"
    exit 1
fi

print_info "Found docker-compose.yml at $COMPOSE_FILE"
echo ""

# Step 1: Backup
print_step "1. Creating backup..."
BACKUP_FILE="$COMPOSE_FILE.backup.$(date +%Y%m%d_%H%M%S)"
cp "$COMPOSE_FILE" "$BACKUP_FILE"
print_info "✓ Backup created: $BACKUP_FILE"
echo ""

# Step 2: Check current configuration
print_step "2. Checking current configuration..."

# Check MCP host setting
if grep -q "mcp-host=127\.0\.0\.1" "$COMPOSE_FILE"; then
    print_warn "Found: --mcp-host=127.0.0.1 (needs to be changed)"
    NEED_FIX_HOST=true
elif grep -q "mcp-host=0\.0\.0\.0" "$COMPOSE_FILE"; then
    print_info "✓ Already configured: --mcp-host=0.0.0.0"
    NEED_FIX_HOST=false
else
    print_warn "MCP host configuration not found (might be commented out)"
    NEED_FIX_HOST=false
fi

# Check port mapping
if grep -q "^[[:space:]]*#.*\${SVR_MCP_PORT}:9382" "$COMPOSE_FILE"; then
    print_warn "Found: Port mapping is commented out (needs to be uncommented)"
    NEED_FIX_PORT=true
elif grep -q "^[[:space:]]*-[[:space:]]*\${SVR_MCP_PORT}:9382" "$COMPOSE_FILE"; then
    print_info "✓ Port mapping is already enabled"
    NEED_FIX_PORT=false
else
    print_warn "Port mapping configuration not found"
    NEED_FIX_PORT=false
fi

echo ""

# Step 3: Apply fixes
print_step "3. Applying fixes..."

if [ "$NEED_FIX_HOST" = true ]; then
    print_info "Changing --mcp-host=127.0.0.1 to --mcp-host=0.0.0.0..."
    sed -i 's/--mcp-host=127\.0\.0\.1/--mcp-host=0.0.0.0/g' "$COMPOSE_FILE"
    print_info "✓ MCP host address updated"
else
    print_info "No need to fix MCP host address"
fi

if [ "$NEED_FIX_PORT" = true ]; then
    print_info "Uncommenting port mapping for ${SVR_MCP_PORT}:9382..."
    # This sed command removes leading spaces and # from the port mapping line
    sed -i 's/^[[:space:]]*#[[:space:]]*\(-[[:space:]]*\${SVR_MCP_PORT}:9382.*\)/      \1/' "$COMPOSE_FILE"
    print_info "✓ Port mapping enabled"
else
    print_info "No need to fix port mapping"
fi

echo ""

# Step 4: Verify changes
print_step "4. Verifying changes..."

echo ""
print_info "MCP configuration in docker-compose.yml:"
echo "---"
grep -A 10 "enable-mcpserver" "$COMPOSE_FILE" | head -n 10 || print_warn "MCP configuration not found in file"
echo "---"
echo ""

print_info "Port mapping configuration:"
echo "---"
grep "SVR_MCP_PORT\|9382" "$COMPOSE_FILE" || print_warn "Port mapping not found in file"
echo "---"
echo ""

# Step 5: Show diff
if command -v diff &> /dev/null; then
    print_step "5. Changes made (diff)..."
    echo ""
    diff -u "$BACKUP_FILE" "$COMPOSE_FILE" || true
    echo ""
fi

# Step 6: Instructions
print_step "6. Next steps..."
echo ""
print_info "Configuration has been updated!"
echo ""
print_info "To apply the changes, restart the Docker containers:"
echo ""
echo "  cd $DOCKER_DIR"
echo "  docker compose down"
echo "  docker compose up -d"
echo ""
print_info "After restart, verify MCP server is running:"
echo ""
echo "  # Check container logs"
echo "  docker logs -f ragflow-server | grep MCP"
echo ""
echo "  # You should see:"
echo "  #   MCP host: 0.0.0.0"
echo "  #   MCP port: 9382"
echo ""
echo "  # Test local access"
echo "  curl http://127.0.0.1:9382/health"
echo ""
print_info "Then configure nginx on the host machine:"
echo ""
echo "  sudo cp /home/user/ragflow/nginx_mcp_standalone.conf /etc/nginx/sites-available/mcp-ragflow"
echo "  sudo ln -s /etc/nginx/sites-available/mcp-ragflow /etc/nginx/sites-enabled/"
echo "  sudo nginx -t"
echo "  sudo systemctl reload nginx"
echo ""
print_info "Finally, test HTTPS access:"
echo ""
echo "  curl https://ddbmcp.xiaofeifei.fun/health"
echo ""
print_warn "Backup file saved at: $BACKUP_FILE"
print_warn "If something goes wrong, restore with:"
echo "  cp $BACKUP_FILE $COMPOSE_FILE"
echo ""
echo "============================================"
print_info "Script completed successfully!"
echo "============================================"
