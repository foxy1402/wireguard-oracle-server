#!/bin/bash

###############################################################################
# WireGuard Ubuntu Complete Fix Script
# This script fixes the most common issue: "Connected but no internet"
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}WireGuard Ubuntu Complete Fix${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Get network interface
echo -e "${BLUE}[1/7]${NC} Detecting network interface..."
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [ -z "$INTERFACE" ]; then
    echo -e "${RED}Could not detect network interface${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Interface: $INTERFACE${NC}"

# Enable IP forwarding
echo -e "${BLUE}[2/7]${NC} Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1 > /dev/null
if ! grep -q "^net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
fi
echo -e "${GREEN}✓ IP forwarding enabled${NC}"

# Clear existing iptables rules for WireGuard
echo -e "${BLUE}[3/7]${NC} Clearing old iptables rules..."
iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o $INTERFACE -j MASQUERADE 2>/dev/null || true
iptables -D FORWARD -i wg0 -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -o wg0 -j ACCEPT 2>/dev/null || true
iptables -D INPUT -p udp --dport 51820 -j ACCEPT 2>/dev/null || true
echo -e "${GREEN}✓ Old rules cleared${NC}"

# Add new iptables rules
echo -e "${BLUE}[4/7]${NC} Adding new iptables rules..."

# CRITICAL: NAT masquerading for internet access
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $INTERFACE -j MASQUERADE

# Allow forwarding to/from WireGuard
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A FORWARD -o wg0 -j ACCEPT

# Allow WireGuard port
iptables -I INPUT 1 -p udp --dport 51820 -j ACCEPT

echo -e "${GREEN}✓ iptables rules added${NC}"

# Make iptables persistent (Ubuntu method)
echo -e "${BLUE}[5/7]${NC} Making iptables rules persistent..."

# Install netfilter-persistent if not installed
if ! command -v netfilter-persistent &>/dev/null; then
    log_info "Installing netfilter-persistent..."
    # Pre-seed debconf to avoid interactive prompts
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent netfilter-persistent >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}! Warning: Could not install netfilter-persistent${NC}"
        echo -e "${YELLOW}! Rules may not persist after reboot${NC}"
    fi
fi

# Save rules
mkdir -p /etc/iptables
if iptables-save > /etc/iptables/rules.v4 2>/dev/null; then
    echo -e "${GREEN}✓ Rules saved to /etc/iptables/rules.v4${NC}"
else
    echo -e "${YELLOW}! Warning: Could not save iptables rules${NC}"
fi

# Enable and start service
systemctl enable netfilter-persistent >/dev/null 2>&1
systemctl start netfilter-persistent >/dev/null 2>&1

echo -e "${GREEN}✓ iptables persistence configured${NC}"

# Configure UFW if present
echo -e "${BLUE}[6/7]${NC} Configuring UFW..."
if command -v ufw &>/dev/null; then
    ufw allow 22/tcp comment 'SSH' >/dev/null 2>&1 || true
    ufw allow 51820/udp comment 'WireGuard VPN' >/dev/null 2>&1 || true
    echo "y" | ufw enable >/dev/null 2>&1 || true
    echo -e "${GREEN}✓ UFW configured${NC}"
else
    echo -e "${YELLOW}! UFW not installed, using iptables only${NC}"
fi

# Fix WireGuard config PostUp/PostDown
echo -e "${BLUE}[7/7]${NC} Updating WireGuard configuration..."
if [ -f /etc/wireguard/wg0.conf ]; then
    # Backup original config with timestamp
    BACKUP_FILE="/etc/wireguard/wg0.conf.backup.$(date +%Y%m%d_%H%M%S)"
    cp /etc/wireguard/wg0.conf "$BACKUP_FILE"
    echo -e "${GREEN}✓ Config backed up to: $BACKUP_FILE${NC}"
    
    # Remove old PostUp/PostDown if they exist
    sed -i '/^PostUp/d' /etc/wireguard/wg0.conf
    sed -i '/^PostDown/d' /etc/wireguard/wg0.conf
    
    # Create a temporary file with new PostUp/PostDown
    TEMP_FILE=$(mktemp)
    awk -v iface="$INTERFACE" '
    /^\[Interface\]/ {
        print $0
        print "PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o " iface " -j MASQUERADE"
        print "PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o " iface " -j MASQUERADE"
        next
    }
    { print }
    ' /etc/wireguard/wg0.conf > "$TEMP_FILE"
    
    # Replace config with updated version
    if [ -s "$TEMP_FILE" ]; then
        cat "$TEMP_FILE" > /etc/wireguard/wg0.conf
        chmod 600 /etc/wireguard/wg0.conf
        rm -f "$TEMP_FILE"
        echo -e "${GREEN}✓ WireGuard config updated${NC}"
    else
        rm -f "$TEMP_FILE"
        echo -e "${RED}✗ Failed to update config${NC}"
    fi
else
    echo -e "${YELLOW}! WireGuard config not found at /etc/wireguard/wg0.conf${NC}"
fi

# Restart WireGuard
echo ""
echo -e "${BLUE}[8/8]${NC} Restarting WireGuard..."
systemctl restart wg-quick@wg0
sleep 2

if systemctl is-active --quiet wg-quick@wg0; then
    echo -e "${GREEN}✓ WireGuard restarted successfully${NC}"
else
    echo -e "${RED}✗ WireGuard failed to restart${NC}"
    echo "Checking logs..."
    journalctl -u wg-quick@wg0 -n 20 --no-pager
fi

# Run verification
echo ""
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}Verification${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""

# Check IP forwarding
IP_FORWARD=$(sysctl -n net.ipv4.ip_forward)
if [ "$IP_FORWARD" = "1" ]; then
    echo -e "${GREEN}✓ IP Forwarding: Enabled${NC}"
else
    echo -e "${RED}✗ IP Forwarding: Disabled${NC}"
fi

# Check WireGuard service
if systemctl is-active --quiet wg-quick@wg0; then
    echo -e "${GREEN}✓ WireGuard Service: Running${NC}"
else
    echo -e "${RED}✗ WireGuard Service: Stopped${NC}"
fi

# Check NAT rule
if iptables -t nat -L POSTROUTING -n | grep -q "MASQUERADE.*10.8.0.0/24"; then
    echo -e "${GREEN}✓ NAT Rule: Configured${NC}"
else
    echo -e "${RED}✗ NAT Rule: Missing${NC}"
fi

# Check WireGuard interface
if ip link show wg0 &>/dev/null; then
    echo -e "${GREEN}✓ WireGuard Interface: Up${NC}"
else
    echo -e "${RED}✗ WireGuard Interface: Down${NC}"
fi

# Check firewall port
if command -v ufw &>/dev/null; then
    if ufw status | grep -q "51820/udp"; then
        echo -e "${GREEN}✓ UFW Port: Open${NC}"
    else
        echo -e "${YELLOW}! UFW Port: Not configured${NC}"
    fi
fi

echo ""
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}Oracle Cloud Security List Instructions${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""
echo -e "${YELLOW}CRITICAL:${NC} You must also configure Oracle Cloud Security List!"
echo ""
echo "1. Go to Oracle Cloud Console: https://cloud.oracle.com"
echo "2. Navigate to: ☰ Menu → Networking → Virtual Cloud Networks"
echo "3. Click your VCN → Security Lists → Default Security List"
echo "4. Click 'Add Ingress Rules'"
echo "5. Enter:"
echo "   - Source CIDR: 0.0.0.0/0"
echo "   - IP Protocol: UDP"
echo "   - Destination Port Range: 51820"
echo "6. Click 'Add Ingress Rules'"
echo ""
echo -e "${YELLOW}Without this step, clients cannot connect!${NC}"
echo ""

# Display current WireGuard status
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}Current WireGuard Status${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""
wg show 2>/dev/null || echo "No active peers"
echo ""

# Test from client instructions
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}Testing from Client${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""
echo "After connecting WireGuard on your device, test with:"
echo ""
echo "  ping 10.8.0.1        # Test connection to WireGuard server"
echo "  ping 8.8.8.8         # Test internet connectivity"
echo "  nslookup google.com  # Test DNS resolution"
echo ""
echo "If ping 10.8.0.1 works but ping 8.8.8.8 fails:"
echo "  → NAT/routing issue (check iptables rules above)"
echo ""
echo "If nothing works:"
echo "  → Check Oracle Cloud Security List configuration"
echo ""

echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}Fix completed!${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo "You can now try connecting from your client device."
echo ""
