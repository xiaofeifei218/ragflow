#!/bin/bash
#
# RAGFlow MCP Server Startup Script
# This script starts the MCP server in self-host mode with HTTPS support via nginx reverse proxy
#

# Configuration
MCP_HOST="127.0.0.1"  # Only listen on localhost for security
MCP_PORT="9382"
RAGFLOW_BASE_URL="http://127.0.0.1:9380"
MODE="self-host"

# API Key - REPLACE THIS with your actual RAGFlow API key
# You can get your API key from RAGFlow web interface: Settings -> API Keys
API_KEY="${RAGFLOW_API_KEY:-ragflow-xxxxx}"

if [ "$API_KEY" = "ragflow-xxxxx" ]; then
    echo "ERROR: Please set RAGFLOW_API_KEY environment variable or edit this script"
    echo "Example: export RAGFLOW_API_KEY=ragflow-your-actual-key"
    exit 1
fi

echo "Starting RAGFlow MCP Server..."
echo "  Host: $MCP_HOST"
echo "  Port: $MCP_PORT"
echo "  Mode: $MODE"
echo "  RAGFlow Base URL: $RAGFLOW_BASE_URL"
echo ""
echo "MCP Server will be accessible via nginx at: https://ddbmcp.xiaofeifei.fun"
echo ""

# Start the MCP server
uv run mcp/server/server.py \
    --host=$MCP_HOST \
    --port=$MCP_PORT \
    --base-url=$RAGFLOW_BASE_URL \
    --mode=$MODE \
    --api-key=$API_KEY

# Note: The server runs on localhost only. Access it via nginx reverse proxy:
# https://ddbmcp.xiaofeifei.fun -> nginx -> http://127.0.0.1:9382
