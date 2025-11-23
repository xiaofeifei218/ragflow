#!/bin/bash
#
# Enable MCP Server in Docker Compose Configuration
# This script uncomments and configures MCP settings in docker-compose.yml
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
echo "  Enable MCP Server in Docker"
echo "============================================"
echo ""

# Check if docker-compose.yml exists
if [ ! -f "$COMPOSE_FILE" ]; then
    print_error "docker-compose.yml not found at $COMPOSE_FILE"
    exit 1
fi

print_info "Found docker-compose.yml"
echo ""

# Step 1: Ask for API key
print_step "1. RAGFlow API Key Setup"
echo ""

if [ -z "$RAGFLOW_API_KEY" ]; then
    print_warn "RAGFLOW_API_KEY environment variable not set"
    echo ""
    echo "Please enter your RAGFlow API key:"
    echo "(You can get it from RAGFlow Web UI: Settings → API Keys)"
    echo ""
    read -p "API Key: " API_KEY

    if [ -z "$API_KEY" ]; then
        print_error "API key cannot be empty"
        exit 1
    fi
else
    API_KEY="$RAGFLOW_API_KEY"
    print_info "Using API key from environment variable"
fi

echo ""

# Step 2: Backup
print_step "2. Creating backup..."
BACKUP_FILE="$COMPOSE_FILE.backup.$(date +%Y%m%d_%H%M%S)"
cp "$COMPOSE_FILE" "$BACKUP_FILE"
print_info "✓ Backup created: $BACKUP_FILE"
echo ""

# Step 3: Check current state
print_step "3. Checking current MCP configuration..."
echo ""

if grep -q "^[[:space:]]*command:" "$COMPOSE_FILE" | grep -v "^[[:space:]]*#"; then
    print_warn "MCP command section appears to be already enabled"
    echo ""
    read -p "Do you want to continue and reconfigure? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        print_info "Exiting without changes"
        exit 0
    fi
fi

# Step 4: Apply changes
print_step "4. Enabling MCP configuration..."
echo ""

# Create a Python script to properly uncomment and configure MCP
python3 << 'PYTHON_SCRIPT'
import re
import sys

compose_file = "/home/user/ragflow/docker/docker-compose.yml"
api_key = sys.argv[1] if len(sys.argv) > 1 else "ragflow-xxxxx"

with open(compose_file, 'r') as f:
    content = f.read()

# Find the ragflow-cpu service section
# Uncomment the command section for MCP

# Pattern to match the commented command block
mcp_pattern = r'(services:\s+ragflow-cpu:.*?)(#\s*command:\s*\n\s*#\s*-\s*--enable-mcpserver\s*\n(?:\s*#[^\n]*\n)*)'

def uncomment_mcp_block(match):
    service_part = match.group(1)
    comment_block = match.group(2)

    # Remove comment markers (#) from the command block
    uncommented = re.sub(r'^\s*#\s*', '    ', comment_block, flags=re.MULTILINE)

    # Replace the API key placeholder
    uncommented = re.sub(
        r'--mcp-host-api-key=ragflow-[^\s\n]*',
        f'--mcp-host-api-key={api_key}',
        uncommented
    )

    # Ensure mcp-host is 0.0.0.0
    uncommented = re.sub(
        r'--mcp-host=127\.0\.0\.1',
        '--mcp-host=0.0.0.0',
        uncommented
    )

    return service_part + uncommented

# Apply the transformation
modified_content = re.sub(mcp_pattern, uncomment_mcp_block, content, flags=re.DOTALL)

# Write back
with open(compose_file, 'w') as f:
    f.write(modified_content)

print("MCP configuration enabled successfully")
PYTHON_SCRIPT "$API_KEY"

if [ $? -eq 0 ]; then
    print_info "✓ MCP configuration enabled"
else
    print_error "Failed to enable MCP configuration"
    print_info "Restoring from backup..."
    cp "$BACKUP_FILE" "$COMPOSE_FILE"
    exit 1
fi

echo ""

# Step 5: Verify changes
print_step "5. Verifying changes..."
echo ""

print_info "MCP configuration in docker-compose.yml:"
echo "---"
grep -A 8 "enable-mcpserver" "$COMPOSE_FILE" || print_warn "Could not find MCP configuration"
echo "---"
echo ""

# Step 6: Check port mapping
print_info "Port mapping:"
echo "---"
grep "SVR_MCP_PORT\|9382" "$COMPOSE_FILE" | head -2
echo "---"
echo ""

# Step 7: Instructions
print_step "6. Next steps"
echo ""

cat << 'EOF'
MCP server has been enabled in docker-compose.yml!

To apply the changes:

  1. Restart Docker containers:
     cd docker
     docker compose down
     docker compose up -d

  2. Verify MCP is running:
     docker logs -f ragflow-server | grep MCP

     You should see:
       MCP host: 0.0.0.0
       MCP port: 9382
       MCP launch mode: self-host

  3. Test MCP endpoint:
     curl -X POST http://localhost:9382/mcp

  4. Configure Claude Desktop:
     See CLAUDE_DESKTOP_SETUP.md for detailed instructions

     Quick config example (claude_desktop_config.json):
     {
       "mcpServers": {
         "ragflow": {
           "command": "curl",
           "args": [
             "-X", "POST",
             "http://YOUR_SERVER_IP:9382/mcp"
           ]
         }
       }
     }

  5. Get your server IP:
     hostname -I
     # Use the first IP for YOUR_SERVER_IP

EOF

echo ""
print_warn "Backup saved at: $BACKUP_FILE"
echo ""
echo "============================================"
print_info "Configuration completed!"
echo "============================================"
