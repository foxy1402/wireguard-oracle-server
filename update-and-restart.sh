#!/bin/bash

###############################################################################
# WireGuard Update and Restart Script
# Use this if you already have WireGuard installed and want to update/restart
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}WireGuard Update & Restart Script${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   echo "Please run: sudo ./update-and-restart.sh"
   exit 1
fi

# Check if WireGuard is installed
if ! command -v wg &>/dev/null; then
    echo -e "${RED}WireGuard is not installed!${NC}"
    echo "Please run the main installation script first:"
    echo "  sudo ./wireguard-oracle-setup.sh"
    exit 1
fi

echo -e "${BLUE}What would you like to do?${NC}"
echo ""
echo "1) Restart WireGuard (quick restart)"
echo "2) Update system packages and restart WireGuard"
echo "3) Apply complete fix (fixes internet connectivity issues)"
echo "4) Restart dashboard only"
echo "5) Update scripts from GitHub and restart"
echo "6) Full system check and restart everything"
echo ""
read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        echo ""
        echo -e "${BLUE}[1/2]${NC} Stopping WireGuard..."
        systemctl stop wg-quick@wg0
        echo -e "${GREEN}✓ Stopped${NC}"
        
        echo -e "${BLUE}[2/2]${NC} Starting WireGuard..."
        systemctl start wg-quick@wg0
        sleep 2
        
        if systemctl is-active --quiet wg-quick@wg0; then
            echo -e "${GREEN}✓ WireGuard restarted successfully!${NC}"
            echo ""
            wg show
        else
            echo -e "${RED}✗ WireGuard failed to start${NC}"
            journalctl -u wg-quick@wg0 -n 20 --no-pager
        fi
        ;;
        
    2)
        echo ""
        echo -e "${BLUE}[1/4]${NC} Updating system packages..."
        dnf update -y wireguard-tools iptables
        echo -e "${GREEN}✓ Packages updated${NC}"
        
        echo -e "${BLUE}[2/4]${NC} Stopping WireGuard..."
        systemctl stop wg-quick@wg0
        echo -e "${GREEN}✓ Stopped${NC}"
        
        echo -e "${BLUE}[3/4]${NC} Starting WireGuard..."
        systemctl start wg-quick@wg0
        sleep 2
        echo -e "${GREEN}✓ Started${NC}"
        
        echo -e "${BLUE}[4/4]${NC} Verifying status..."
        if systemctl is-active --quiet wg-quick@wg0; then
            echo -e "${GREEN}✓ WireGuard is running!${NC}"
            echo ""
            wg show
        else
            echo -e "${RED}✗ WireGuard failed to start${NC}"
        fi
        ;;
        
    3)
        echo ""
        echo -e "${BLUE}Running complete fix script...${NC}"
        echo ""
        if [ -f ./complete-fix.sh ]; then
            chmod +x ./complete-fix.sh
            ./complete-fix.sh
        else
            echo -e "${RED}complete-fix.sh not found!${NC}"
            echo "Please make sure you're in the correct directory."
        fi
        ;;
        
    4)
        echo ""
        if systemctl list-unit-files | grep -q "wireguard-dashboard.service"; then
            echo -e "${BLUE}[1/2]${NC} Stopping dashboard..."
            systemctl stop wireguard-dashboard
            echo -e "${GREEN}✓ Stopped${NC}"
            
            echo -e "${BLUE}[2/2]${NC} Starting dashboard..."
            systemctl start wireguard-dashboard
            sleep 2
            
            if systemctl is-active --quiet wireguard-dashboard; then
                echo -e "${GREEN}✓ Dashboard restarted successfully!${NC}"
                echo ""
                PUBLIC_IP=$(curl -s ifconfig.me)
                echo "Access dashboard at: http://${PUBLIC_IP}:8080"
            else
                echo -e "${RED}✗ Dashboard failed to start${NC}"
                journalctl -u wireguard-dashboard -n 20 --no-pager
            fi
        else
            echo -e "${YELLOW}Dashboard is not installed.${NC}"
            echo ""
            read -p "Would you like to install it now? (y/n): " install_dash
            if [ "$install_dash" = "y" ] || [ "$install_dash" = "Y" ]; then
                if [ -f ./install-dashboard.sh ]; then
                    chmod +x ./install-dashboard.sh
                    ./install-dashboard.sh
                else
                    echo -e "${RED}install-dashboard.sh not found!${NC}"
                fi
            fi
        fi
        ;;
        
    5)
        echo ""
        echo -e "${BLUE}[1/3]${NC} Checking for script updates..."
        if command -v git &>/dev/null && [ -d .git ]; then
            git pull
            echo -e "${GREEN}✓ Scripts updated${NC}"
        else
            echo -e "${YELLOW}! Not a git repository. Download latest version manually from GitHub.${NC}"
        fi
        
        echo -e "${BLUE}[2/3]${NC} Making scripts executable..."
        chmod +x *.sh
        echo -e "${GREEN}✓ Done${NC}"
        
        echo -e "${BLUE}[3/3]${NC} Restarting WireGuard..."
        systemctl restart wg-quick@wg0
        sleep 2
        
        if systemctl is-active --quiet wg-quick@wg0; then
            echo -e "${GREEN}✓ WireGuard restarted successfully!${NC}"
        else
            echo -e "${RED}✗ WireGuard failed to restart${NC}"
        fi
        ;;
        
    6)
        echo ""
        echo -e "${BLUE}[1/5]${NC} Running health check..."
        if [ -f ./health-check.sh ]; then
            chmod +x ./health-check.sh
            ./health-check.sh
        else
            echo -e "${YELLOW}health-check.sh not found, skipping...${NC}"
        fi
        
        echo ""
        echo -e "${BLUE}[2/5]${NC} Checking IP forwarding..."
        sysctl -w net.ipv4.ip_forward=1
        echo -e "${GREEN}✓ Enabled${NC}"
        
        echo -e "${BLUE}[3/5]${NC} Restarting WireGuard..."
        systemctl restart wg-quick@wg0
        sleep 2
        echo -e "${GREEN}✓ Done${NC}"
        
        echo -e "${BLUE}[4/5]${NC} Restarting dashboard (if installed)..."
        if systemctl list-unit-files | grep -q "wireguard-dashboard.service"; then
            systemctl restart wireguard-dashboard
            echo -e "${GREEN}✓ Dashboard restarted${NC}"
        else
            echo -e "${YELLOW}! Dashboard not installed, skipping${NC}"
        fi
        
        echo -e "${BLUE}[5/5]${NC} Running final diagnostics..."
        echo ""
        ./wireguard-oracle-setup.sh --diagnose 2>/dev/null || echo "Run diagnostics manually if needed."
        
        echo ""
        echo -e "${GREEN}=============================================${NC}"
        echo -e "${GREEN}All services restarted!${NC}"
        echo -e "${GREEN}=============================================${NC}"
        ;;
        
    *)
        echo -e "${RED}Invalid choice. Please run the script again.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}Quick Commands Reference${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""
echo "Check WireGuard status:"
echo "  sudo wg show"
echo ""
echo "View WireGuard logs:"
echo "  sudo journalctl -u wg-quick@wg0 -f"
echo ""
echo "Test connection from your device:"
echo "  ping 10.8.0.1        # Test VPN server"
echo "  ping 8.8.8.8         # Test internet"
echo ""
echo "Add new client:"
echo "  sudo ./wireguard-oracle-setup.sh --add-client <name>"
echo ""
echo "Fix connectivity issues:"
echo "  sudo ./complete-fix.sh"
echo ""

echo -e "${GREEN}Done!${NC}"
