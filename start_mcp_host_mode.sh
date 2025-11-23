#!/bin/bash
#
# RAGFlow MCP Server Startup Script (Host Mode)
# This script starts the MCP server in host mode for multi-tenant access
#

# Configuration
MCP_HOST="127.0.0.1"
MCP_PORT="9382"
RAGFLOW_BASE_URL="http://127.0.0.1:9380"
LAUNCH_MODE="host"

# Transport settings
# Note: In host mode, streamable-http transport is not supported yet
# So we disable it and only use SSE transport
TRANSPORT_SSE_ENABLED="--transport-sse-enabled"
TRANSPORT_STREAMABLE_HTTP_ENABLED="--no-transport-streamable-http-enabled"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}RAGFlow MCP Server - Host Mode${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Host: $MCP_HOST"
echo "  Port: $MCP_PORT"
echo "  RAGFlow Base URL: $RAGFLOW_BASE_URL"
echo "  Mode: $LAUNCH_MODE (multi-tenant)"
echo "  Transport: SSE only (streamable-HTTP not supported in host mode)"
echo ""
echo -e "${YELLOW}Note:${NC} In host mode, each client must provide an API key in the request headers."
echo ""

# Check if RAGFlow server is running
echo -e "${YELLOW}Checking RAGFlow server...${NC}"
if curl -s -o /dev/null -w "%{http_code}" "$RAGFLOW_BASE_URL/api/v1/health" 2>/dev/null | grep -q "200\|404"; then
    echo -e "${GREEN}✓ RAGFlow server is running${NC}"
else
    echo -e "${RED}✗ Warning: RAGFlow server may not be running at $RAGFLOW_BASE_URL${NC}"
    echo -e "${YELLOW}  Please ensure RAGFlow is started before proceeding.${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Start MCP server
echo ""
echo -e "${GREEN}Starting MCP Server...${NC}"
echo ""

uv run mcp/server/server.py \
    --host="$MCP_HOST" \
    --port="$MCP_PORT" \
    --base-url="$RAGFLOW_BASE_URL" \
    --mode="$LAUNCH_MODE" \
    $TRANSPORT_SSE_ENABLED \
    $TRANSPORT_STREAMABLE_HTTP_ENABLED
