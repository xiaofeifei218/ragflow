#!/bin/bash
#
# DNS Configuration Checker and Fixer for MCP Domain
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

MCP_DOMAIN="ddbmcp.xiaofeifei.fun"
PARENT_DOMAIN="xiaofeifei.fun"

echo "============================================"
echo "  DNS Configuration Checker"
echo "============================================"
echo ""

# Step 1: Check DNS resolution
print_step "1. Checking DNS resolution for $MCP_DOMAIN"
echo ""

DNS_RESULT=$(dig +short "$MCP_DOMAIN" 2>/dev/null)

if [ -z "$DNS_RESULT" ]; then
    print_error "✗ DNS resolution failed for $MCP_DOMAIN"
    print_warn "  The domain does not resolve to any IP address"
    DNS_CONFIGURED=false
else
    print_info "✓ DNS resolved to: $DNS_RESULT"
    DNS_CONFIGURED=true
fi
echo ""

# Step 2: Check parent domain
print_step "2. Checking parent domain $PARENT_DOMAIN"
echo ""

PARENT_DNS=$(dig +short "$PARENT_DOMAIN" 2>/dev/null)

if [ -z "$PARENT_DNS" ]; then
    print_warn "Parent domain $PARENT_DOMAIN also does not resolve"
else
    print_info "✓ Parent domain resolves to: $PARENT_DNS"
fi
echo ""

# Step 3: Get server's public IP
print_step "3. Detecting server's public IP address"
echo ""

# Try multiple methods to get public IP
PUBLIC_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || curl -s -4 ipinfo.io/ip 2>/dev/null)

if [ -z "$PUBLIC_IP" ]; then
    print_warn "Could not detect public IP automatically"
    print_info "Please check your public IP manually:"
    echo "  curl ifconfig.me"
else
    print_info "✓ Server's public IP: $PUBLIC_IP"
fi
echo ""

# Step 4: Check local IP
print_step "4. Checking local/private IP addresses"
echo ""

print_info "Local network interfaces:"
ip -4 addr show | grep inet | grep -v 127.0.0.1 | awk '{print "  " $NF ": " $2}' || \
hostname -I | tr ' ' '\n' | grep -v '^$' | awk '{print "  " $1}'
echo ""

# Step 5: Analysis and solutions
print_step "5. Analysis and Solutions"
echo ""

if [ "$DNS_CONFIGURED" = false ]; then
    print_error "PROBLEM: DNS is not configured for $MCP_DOMAIN"
    echo ""
    echo "You have TWO options to fix this:"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  OPTION 1: Configure DNS (Recommended for production)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "You need to add a DNS record at your domain registrar or DNS provider."
    echo ""
    echo "DNS Record Type: A Record"
    echo "  Host/Name: ddbmcp"
    echo "  Type: A"
    echo "  Value: $PUBLIC_IP  ← Your server's public IP"
    echo "  TTL: 300 (or default)"
    echo ""
    echo "Alternative: CNAME Record (if you already have a domain pointing to this server)"
    echo "  Host/Name: ddbmcp"
    echo "  Type: CNAME"
    echo "  Value: your-main-domain.com"
    echo "  TTL: 300 (or default)"
    echo ""
    echo "Steps:"
    echo "  1. Login to your DNS provider (where you manage $PARENT_DOMAIN)"
    echo "  2. Go to DNS settings / DNS records"
    echo "  3. Add a new A record:"
    echo "     - Name/Host: ddbmcp"
    echo "     - Type: A"
    echo "     - IP: $PUBLIC_IP"
    echo "  4. Save and wait 5-10 minutes for DNS propagation"
    echo "  5. Test: dig ddbmcp.xiaofeifei.fun"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  OPTION 2: Use /etc/hosts (Quick test, local only)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "For LOCAL testing only (won't work from other machines):"
    echo ""
    echo "Add to /etc/hosts:"
    echo "  127.0.0.1  $MCP_DOMAIN"
    echo ""
    echo "Command:"
    echo "  echo '127.0.0.1  $MCP_DOMAIN' | sudo tee -a /etc/hosts"
    echo ""
    echo "Then test:"
    echo "  curl https://$MCP_DOMAIN/health --insecure"
    echo ""
    echo "⚠️  WARNING: This only works on THIS machine!"
    echo "⚠️  Other machines won't be able to access the domain."
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  OPTION 3: Use IP address directly (No domain)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Configure nginx to accept requests by IP:"
    echo ""
    echo "Nginx config change:"
    echo "  server_name $MCP_DOMAIN;"
    echo "  →"
    echo "  server_name $MCP_DOMAIN $PUBLIC_IP;"
    echo ""
    echo "Then access via:"
    echo "  https://$PUBLIC_IP/health"
    echo ""
    echo "⚠️  WARNING: SSL certificate won't match IP address!"
    echo "⚠️  You'll get certificate errors."
    echo ""
else
    print_info "✓ DNS is configured and resolving correctly"
    echo ""
    print_info "DNS points to: $DNS_RESULT"

    if [ "$DNS_RESULT" = "$PUBLIC_IP" ]; then
        print_info "✓ DNS matches server's public IP"
    else
        print_warn "⚠ DNS ($DNS_RESULT) does not match public IP ($PUBLIC_IP)"
        echo ""
        echo "This might be OK if:"
        echo "  - You're behind a reverse proxy / load balancer"
        echo "  - You're using a CDN"
        echo "  - Server has multiple IPs"
        echo ""
        echo "If this is NOT expected, update your DNS A record to: $PUBLIC_IP"
    fi
fi
echo ""

# Step 6: Quick DNS commands
print_step "6. Useful DNS testing commands"
echo ""

cat << 'EOF'
# Check DNS resolution
dig ddbmcp.xiaofeifei.fun
dig +short ddbmcp.xiaofeifei.fun

# Check with specific DNS servers
dig @8.8.8.8 ddbmcp.xiaofeifei.fun        # Google DNS
dig @1.1.1.1 ddbmcp.xiaofeifei.fun        # Cloudflare DNS

# Check DNS propagation status (in browser)
# https://www.whatsmydns.net/#A/ddbmcp.xiaofeifei.fun

# Test with curl (bypass DNS, use hosts file)
curl --resolve ddbmcp.xiaofeifei.fun:443:127.0.0.1 https://ddbmcp.xiaofeifei.fun/health -k

# Clear DNS cache (if needed)
sudo systemd-resolve --flush-caches  # systemd
sudo resolvectl flush-caches         # newer systemd
sudo /etc/init.d/nscd restart        # nscd
EOF

echo ""

# Step 7: Interactive fix option
print_step "7. Quick Fix Option"
echo ""

if [ "$DNS_CONFIGURED" = false ]; then
    echo "Would you like to add a temporary /etc/hosts entry for LOCAL testing? (y/n)"
    echo "(This will only work on THIS machine)"
    echo ""
    read -p "Add to /etc/hosts? (y/n): " -r ADD_HOSTS

    if [ "$ADD_HOSTS" = "y" ] || [ "$ADD_HOSTS" = "Y" ]; then
        # Check if entry already exists
        if grep -q "$MCP_DOMAIN" /etc/hosts 2>/dev/null; then
            print_warn "Entry already exists in /etc/hosts"
            print_info "Current entry:"
            grep "$MCP_DOMAIN" /etc/hosts
        else
            echo "127.0.0.1  $MCP_DOMAIN" | sudo tee -a /etc/hosts > /dev/null
            print_info "✓ Added to /etc/hosts:"
            grep "$MCP_DOMAIN" /etc/hosts
            echo ""
            print_info "Now you can test with:"
            echo "  curl http://127.0.0.1:9382/health"
            echo "  curl https://$MCP_DOMAIN/health --insecure"
        fi
    else
        print_info "Skipping /etc/hosts modification"
        echo ""
        print_info "To configure DNS properly, follow OPTION 1 above"
    fi
fi

echo ""
echo "============================================"
print_info "DNS check completed!"
echo "============================================"
