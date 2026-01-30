#!/bin/bash

###############################################################################
# WireGuard Oracle Cloud Complete Fix Script
# This script fixes the most common issue: "Connected but no internet"
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}WireGuard Oracle Cloud Complete Fix${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Get network interface
echo -e "${BLUE}[1/8]${NC} Detecting network interface..."
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [ -z "$INTERFACE" ]; then
    echo -e "${RED}Could not detect network interface${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Interface: $INTERFACE${NC}"

# Enable IP forwarding
echo -e "${BLUE}[2/8]${NC} Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1 > /dev/null
if ! grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
fi
echo -e "${GREEN}✓ IP forwarding enabled${NC}"

# Clear existing iptables rules for WireGuard
echo -e "${BLUE}[3/8]${NC} Clearing old iptables rules..."
iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o $INTERFACE -j MASQUERADE 2>/dev/null || true
iptables -D FORWARD -i wg0 -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -o wg0 -j ACCEPT 2>/dev/null || true
iptables -D INPUT -p udp --dport 51820 -j ACCEPT 2>/dev/null || true
echo -e "${GREEN}✓ Old rules cleared${NC}"

# Add new iptables rules
echo -e "${BLUE}[4/8]${NC} Adding new iptables rules..."

# CRITICAL: NAT masquerading for internet access
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $INTERFACE -j MASQUERADE

# Allow forwarding to/from WireGuard
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A FORWARD -o wg0 -j ACCEPT

# Allow WireGuard port
iptables -I INPUT 1 -p udp --dport 51820 -j ACCEPT

echo -e "${GREEN}✓ iptables rules added${NC}"

# Make iptables persistent
echo -e "${BLUE}[5/8]${NC} Making iptables rules persistent..."
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

# Create systemd service for iptables restore
cat > /etc/systemd/system/iptables-restore.service <<EOF
[Unit]
Description=Restore iptables rules
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables/rules.v4
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable iptables-restore.service
echo -e "${GREEN}✓ iptables persistence configured${NC}"

# Configure firewalld
echo -e "${BLUE}[6/8]${NC} Configuring firewalld..."
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-port=51820/udp 2>/dev/null || true
    firewall-cmd --permanent --zone=public --add-masquerade 2>/dev/null || true
    
    # Add direct rule for WireGuard
    firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 -o $INTERFACE -j MASQUERADE 2>/dev/null || true
    firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i wg0 -j ACCEPT 2>/dev/null || true
    firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -o wg0 -j ACCEPT 2>/dev/null || true
    
    firewall-cmd --reload
    echo -e "${GREEN}✓ firewalld configured${NC}"
else
    echo -e "${YELLOW}! firewalld not active, skipping${NC}"
fi

# Check and handle SELinux if it's blocking
echo -e "${BLUE}[6.5/8]${NC} Checking SELinux status..."
if command -v getenforce &>/dev/null; then
    SELINUX_STATUS=$(getenforce)
    if [ "$SELINUX_STATUS" = "Enforcing" ]; then
        echo -e "${YELLOW}! SELinux is in Enforcing mode${NC}"
        echo -e "${YELLOW}  This can sometimes block WireGuard traffic${NC}"
        echo -e "${BLUE}  Setting SELinux to Permissive mode...${NC}"
        setenforce 0
        echo -e "${GREEN}✓ SELinux set to Permissive (temporary)${NC}"
        echo -e "${YELLOW}  Note: To make permanent, edit /etc/selinux/config${NC}"
    else
        echo -e "${GREEN}✓ SELinux is not blocking (${SELINUX_STATUS})${NC}"
    fi
else
    echo -e "${GREEN}✓ SELinux not installed${NC}"
fi

# Fix WireGuard config PostUp/PostDown
echo -e "${BLUE}[7/8]${NC} Updating WireGuard configuration..."
if [ -f /etc/wireguard/wg0.conf ]; then
    # Backup original config
    cp /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.backup
    
    # Remove old PostUp/PostDown if they exist
    sed -i '/^PostUp/d' /etc/wireguard/wg0.conf
    sed -i '/^PostDown/d' /etc/wireguard/wg0.conf
    
    # Add new PostUp/PostDown after [Interface] section
    sed -i "/^\[Interface\]/a PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE\nPostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $INTERFACE -j MASQUERADE" /etc/wireguard/wg0.conf
    
    echo -e "${GREEN}✓ WireGuard config updated${NC}"
else
    echo -e "${YELLOW}! WireGuard config not found at /etc/wireguard/wg0.conf${NC}"
fi

# Restart WireGuard
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
if systemctl is-active --quiet firewalld; then
    if firewall-cmd --list-ports | grep -q "51820/udp"; then
        echo -e "${GREEN}✓ Firewall Port: Open${NC}"
    else
        echo -e "${YELLOW}! Firewall Port: Not configured in firewalld${NC}"
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
echo -e "${BLUE}Testing from Windows Client${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""
echo "After connecting WireGuard on Windows, test with:"
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
echo "You can now try connecting from your Windows 11 client."
echo ""
