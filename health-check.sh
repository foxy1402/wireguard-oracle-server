#!/bin/bash

###############################################################################
# WireGuard Health Check Script
# Quick verification that everything is working correctly
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   WireGuard Health Check              ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo ""

PASS=0
FAIL=0
WARN=0

check() {
    local name=$1
    local command=$2
    local expected=$3
    
    echo -n "Checking $name... "
    
    if eval "$command" 2>/dev/null | grep -q "$expected"; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAIL++))
        return 1
    fi
}

warn_check() {
    local name=$1
    local command=$2
    local expected=$3
    
    echo -n "Checking $name... "
    
    if eval "$command" 2>/dev/null | grep -q "$expected"; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASS++))
        return 0
    else
        echo -e "${YELLOW}⚠ WARNING${NC}"
        ((WARN++))
        return 1
    fi
}

# Core checks
echo -e "${BLUE}=== Core System Checks ===${NC}"
check "WireGuard installed" "wg --version" "wireguard"
check "IP forwarding enabled" "sysctl net.ipv4.ip_forward" "= 1"
check "WireGuard service running" "systemctl is-active wg-quick@wg0" "active"
check "WireGuard interface up" "ip link show wg0" "state UP"

echo ""
echo -e "${BLUE}=== Network Configuration ===${NC}"
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
echo -e "Primary interface: ${GREEN}$INTERFACE${NC}"

check "NAT masquerade rule" "iptables -t nat -L POSTROUTING -n" "MASQUERADE.*10.8.0.0/24"
check "FORWARD rule (wg0 in)" "iptables -L FORWARD -n" "ACCEPT.*wg0"
check "INPUT rule (port 51820)" "iptables -L INPUT -n" "udp dpt:51820"

echo ""
echo -e "${BLUE}=== Firewall Configuration ===${NC}"
if systemctl is-active --quiet firewalld; then
    warn_check "firewalld port 51820" "firewall-cmd --list-ports" "51820/udp"
    warn_check "firewalld masquerading" "firewall-cmd --list-all" "masquerade: yes"
else
    echo -e "firewalld: ${YELLOW}Not running (using iptables only)${NC}"
    ((WARN++))
fi

echo ""
echo -e "${BLUE}=== WireGuard Configuration ===${NC}"
if [ -f /etc/wireguard/wg0.conf ]; then
    echo -e "Server config: ${GREEN}Found${NC}"
    ((PASS++))
    
    # Count clients
    CLIENT_COUNT=$(grep -c "^\[Peer\]" /etc/wireguard/wg0.conf 2>/dev/null || echo "0")
    echo -e "Configured clients: ${GREEN}$CLIENT_COUNT${NC}"
    
    # Check if server keys exist
    if [ -f /etc/wireguard/server_private.key ]; then
        echo -e "Server keys: ${GREEN}Found${NC}"
        ((PASS++))
    else
        echo -e "Server keys: ${RED}Missing${NC}"
        ((FAIL++))
    fi
else
    echo -e "Server config: ${RED}Not found${NC}"
    ((FAIL++))
fi

echo ""
echo -e "${BLUE}=== Active Connections ===${NC}"
if command -v wg &>/dev/null; then
    WG_OUTPUT=$(wg show 2>/dev/null)
    if [ -z "$WG_OUTPUT" ]; then
        echo -e "${YELLOW}No active peer connections${NC}"
    else
        PEER_COUNT=$(echo "$WG_OUTPUT" | grep -c "^peer:" || echo "0")
        echo -e "Active peers: ${GREEN}$PEER_COUNT${NC}"
        echo ""
        echo "$WG_OUTPUT"
    fi
else
    echo -e "${RED}WireGuard tools not installed${NC}"
    ((FAIL++))
fi

echo ""
echo -e "${BLUE}=== Persistence Checks ===${NC}"
check "IP forward in sysctl.conf" "cat /etc/sysctl.conf" "net.ipv4.ip_forward = 1"

if [ -f /etc/iptables/rules.v4 ]; then
    echo -e "iptables rules saved: ${GREEN}Yes${NC}"
    ((PASS++))
else
    echo -e "iptables rules saved: ${YELLOW}No (may not persist on reboot)${NC}"
    ((WARN++))
fi

if [ -f /etc/systemd/system/iptables-restore.service ]; then
    if systemctl is-enabled iptables-restore.service &>/dev/null; then
        echo -e "iptables restore service: ${GREEN}Enabled${NC}"
        ((PASS++))
    else
        echo -e "iptables restore service: ${YELLOW}Not enabled${NC}"
        ((WARN++))
    fi
else
    echo -e "iptables restore service: ${YELLOW}Not configured${NC}"
    ((WARN++))
fi

# Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Summary                              ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo ""
echo -e "Passed:   ${GREEN}$PASS${NC}"
echo -e "Failed:   ${RED}$FAIL${NC}"
echo -e "Warnings: ${YELLOW}$WARN${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Configure Oracle Cloud Security List (UDP 51820)"
    echo "2. Download client config: /etc/wireguard/client_*.conf"
    echo "3. Import to WireGuard client and connect"
    echo "4. Test with: ping 10.8.0.1 then ping 8.8.8.8"
    echo ""
    if [ $WARN -gt 0 ]; then
        echo -e "${YELLOW}Note: Some warnings were found but they may not affect functionality${NC}"
    fi
    exit 0
else
    echo -e "${RED}✗ Some critical checks failed${NC}"
    echo ""
    echo -e "${YELLOW}Recommended actions:${NC}"
    echo "1. Run: sudo ./complete-fix.sh"
    echo "2. Check the TROUBLESHOOTING.md guide"
    echo "3. Run this health check again"
    echo ""
    exit 1
fi
