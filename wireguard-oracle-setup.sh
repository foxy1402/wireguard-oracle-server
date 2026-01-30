#!/bin/bash

###############################################################################
# WireGuard Smart Setup Script for Oracle Linux 8 (ARM)
# Features: Auto-detection, self-healing, and comprehensive troubleshooting
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

log_info "Starting WireGuard Smart Setup for Oracle Linux 8..."

###############################################################################
# Step 1: Detect Network Configuration
###############################################################################

detect_network() {
    log_info "Detecting network configuration..."
    
    # Get primary network interface
    PRIMARY_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -z "$PRIMARY_INTERFACE" ]; then
        log_error "Could not detect primary network interface"
        exit 1
    fi
    log_success "Primary interface: $PRIMARY_INTERFACE"
    
    # Get public IP
    PUBLIC_IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || echo "")
    if [ -z "$PUBLIC_IP" ]; then
        log_warning "Could not detect public IP automatically"
        read -p "Enter your Oracle instance public IP: " PUBLIC_IP
    fi
    log_success "Public IP: $PUBLIC_IP"
    
    # Get private IP
    PRIVATE_IP=$(ip -4 addr show $PRIMARY_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    log_success "Private IP: $PRIVATE_IP"
}

###############################################################################
# Step 2: Install WireGuard
###############################################################################

install_wireguard() {
    log_info "Installing WireGuard..."
    
    # Enable EPEL repository
    if ! rpm -q epel-release &>/dev/null; then
        dnf install -y oracle-epel-release-el8
        log_success "EPEL repository enabled"
    fi
    
    # Install WireGuard tools
    if ! command -v wg &>/dev/null; then
        dnf install -y wireguard-tools
        log_success "WireGuard tools installed"
    else
        log_success "WireGuard tools already installed"
    fi
    
    # Install additional tools
    dnf install -y iptables qrencode -y
}

###############################################################################
# Step 3: Configure IP Forwarding
###############################################################################

configure_ip_forwarding() {
    log_info "Configuring IP forwarding..."
    
    # Enable IPv4 forwarding
    if ! grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    fi
    sysctl -w net.ipv4.ip_forward=1 &>/dev/null
    
    # Disable IPv6 forwarding (optional, for security)
    if ! grep -q "net.ipv6.conf.all.forwarding = 0" /etc/sysctl.conf; then
        echo "net.ipv6.conf.all.forwarding = 0" >> /etc/sysctl.conf
    fi
    sysctl -w net.ipv6.conf.all.forwarding=0 &>/dev/null
    
    log_success "IP forwarding configured"
}

###############################################################################
# Step 4: Configure Firewall (Oracle Cloud + firewalld)
###############################################################################

configure_firewall() {
    log_info "Configuring firewall..."
    
    # Configure firewalld
    if systemctl is-active --quiet firewalld; then
        log_info "Configuring firewalld..."
        
        # Add WireGuard port
        firewall-cmd --permanent --add-port=51820/udp
        
        # Add masquerading for WireGuard interface
        firewall-cmd --permanent --zone=public --add-masquerade
        
        # Reload firewall
        firewall-cmd --reload
        
        log_success "firewalld configured"
    else
        log_warning "firewalld is not active"
    fi
    
    # Configure iptables for Oracle Cloud
    log_info "Configuring iptables for Oracle Cloud..."
    
    # Allow WireGuard port
    iptables -I INPUT -p udp --dport 51820 -j ACCEPT
    
    # Configure NAT/Masquerading
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $PRIMARY_INTERFACE -j MASQUERADE
    
    # Allow forwarding
    iptables -A FORWARD -i wg0 -j ACCEPT
    iptables -A FORWARD -o wg0 -j ACCEPT
    
    # Save iptables rules
    if command -v iptables-save &>/dev/null; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
    
    log_success "iptables configured"
    
    # Instructions for Oracle Cloud Console
    log_warning "IMPORTANT: You must also configure Oracle Cloud Security List:"
    log_warning "1. Go to Oracle Cloud Console"
    log_warning "2. Navigate to: Networking > Virtual Cloud Networks > Your VCN > Security Lists"
    log_warning "3. Add Ingress Rule: Source: 0.0.0.0/0, Protocol: UDP, Port: 51820"
}

###############################################################################
# Step 5: Generate WireGuard Keys
###############################################################################

generate_keys() {
    log_info "Generating WireGuard keys..."
    
    mkdir -p /etc/wireguard
    cd /etc/wireguard
    
    # Generate server keys
    if [ ! -f server_private.key ]; then
        wg genkey | tee server_private.key | wg pubkey > server_public.key
        chmod 600 server_private.key
        log_success "Server keys generated"
    else
        log_success "Server keys already exist"
    fi
    
    SERVER_PRIVATE_KEY=$(cat server_private.key)
    SERVER_PUBLIC_KEY=$(cat server_public.key)
}

###############################################################################
# Step 6: Create WireGuard Server Configuration
###############################################################################

create_server_config() {
    log_info "Creating WireGuard server configuration..."
    
    cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
# Server Configuration
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = $SERVER_PRIVATE_KEY

# PostUp and PostDown rules for iptables
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $PRIMARY_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $PRIMARY_INTERFACE -j MASQUERADE

# MTU optimization
MTU = 1420

EOF
    
    chmod 600 /etc/wireguard/wg0.conf
    log_success "Server configuration created"
}

###############################################################################
# Step 7: Add Client Configuration
###############################################################################

add_client() {
    local CLIENT_NAME=$1
    local CLIENT_NUMBER=$2
    
    log_info "Adding client: $CLIENT_NAME..."
    
    # Generate client keys
    CLIENT_PRIVATE_KEY=$(wg genkey)
    CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)
    CLIENT_PRESHARED_KEY=$(wg genpsk)
    
    # Client IP
    CLIENT_IP="10.8.0.$CLIENT_NUMBER/32"
    
    # Add client to server config
    cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
# $CLIENT_NAME
PublicKey = $CLIENT_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
AllowedIPs = $CLIENT_IP

EOF
    
    # Create client config file
    cat > /etc/wireguard/client_$CLIENT_NAME.conf <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = 10.8.0.$CLIENT_NUMBER/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1420

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
Endpoint = $PUBLIC_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25

EOF
    
    log_success "Client $CLIENT_NAME added"
    
    # Generate QR code
    log_info "Generating QR code for $CLIENT_NAME..."
    qrencode -t ansiutf8 < /etc/wireguard/client_$CLIENT_NAME.conf
    
    echo ""
    log_success "Client config saved to: /etc/wireguard/client_$CLIENT_NAME.conf"
}

###############################################################################
# Step 8: Start WireGuard Service
###############################################################################

start_wireguard() {
    log_info "Starting WireGuard service..."
    
    # Enable and start WireGuard
    systemctl enable wg-quick@wg0
    systemctl restart wg-quick@wg0
    
    # Wait a moment for interface to come up
    sleep 2
    
    if systemctl is-active --quiet wg-quick@wg0; then
        log_success "WireGuard service is running"
    else
        log_error "WireGuard service failed to start"
        systemctl status wg-quick@wg0
        exit 1
    fi
}

###############################################################################
# Step 9: Diagnostic and Troubleshooting
###############################################################################

run_diagnostics() {
    log_info "Running diagnostics..."
    
    echo ""
    echo "===== Network Configuration ====="
    echo "Primary Interface: $PRIMARY_INTERFACE"
    echo "Public IP: $PUBLIC_IP"
    echo "Private IP: $PRIVATE_IP"
    
    echo ""
    echo "===== IP Forwarding Status ====="
    sysctl net.ipv4.ip_forward
    
    echo ""
    echo "===== WireGuard Interface Status ====="
    ip addr show wg0 2>/dev/null || echo "wg0 interface not found"
    
    echo ""
    echo "===== WireGuard Peers ====="
    wg show
    
    echo ""
    echo "===== Firewall Rules (iptables) ====="
    echo "NAT Rules:"
    iptables -t nat -L POSTROUTING -n -v | grep -i masq || echo "No masquerade rules found"
    
    echo ""
    echo "FORWARD Rules:"
    iptables -L FORWARD -n -v | grep wg0 || echo "No wg0 forward rules found"
    
    echo ""
    echo "INPUT Rules (UDP 51820):"
    iptables -L INPUT -n -v | grep 51820 || echo "No rules for port 51820 found"
    
    echo ""
    echo "===== firewalld Status ====="
    if systemctl is-active --quiet firewalld; then
        firewall-cmd --list-all
    else
        echo "firewalld is not active"
    fi
    
    echo ""
}

###############################################################################
# Step 10: Auto-Fix Common Issues
###############################################################################

auto_fix() {
    log_info "Running auto-fix for common issues..."
    
    # Fix 1: Ensure IP forwarding is enabled
    if [ "$(sysctl -n net.ipv4.ip_forward)" != "1" ]; then
        log_warning "IP forwarding is disabled, enabling..."
        sysctl -w net.ipv4.ip_forward=1
        log_success "IP forwarding enabled"
    fi
    
    # Fix 2: Check and fix iptables NAT rules
    if ! iptables -t nat -L POSTROUTING -n | grep -q "MASQUERADE.*10.8.0.0/24"; then
        log_warning "NAT masquerade rule missing, adding..."
        iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $PRIMARY_INTERFACE -j MASQUERADE
        log_success "NAT rule added"
    fi
    
    # Fix 3: Check WireGuard interface
    if ! ip link show wg0 &>/dev/null; then
        log_warning "WireGuard interface is down, restarting..."
        systemctl restart wg-quick@wg0
        sleep 2
        log_success "WireGuard restarted"
    fi
    
    # Fix 4: Ensure firewall allows UDP 51820
    if systemctl is-active --quiet firewalld; then
        if ! firewall-cmd --list-ports | grep -q "51820/udp"; then
            log_warning "Firewall rule for 51820/udp missing, adding..."
            firewall-cmd --permanent --add-port=51820/udp
            firewall-cmd --reload
            log_success "Firewall rule added"
        fi
    fi
    
    # Fix 5: Make iptables rules persistent
    log_info "Saving iptables rules..."
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    
    log_success "Auto-fix completed"
}

###############################################################################
# Main Installation Flow
###############################################################################

main() {
    detect_network
    install_wireguard
    configure_ip_forwarding
    configure_firewall
    generate_keys
    create_server_config
    
    # Add first client
    add_client "windows11" 2
    
    start_wireguard
    auto_fix
    run_diagnostics
    
    echo ""
    log_success "============================================="
    log_success "WireGuard installation completed!"
    log_success "============================================="
    echo ""
    log_info "Client configuration file: /etc/wireguard/client_windows11.conf"
    echo ""
    log_warning "NEXT STEPS:"
    echo "1. Download the client config: /etc/wireguard/client_windows11.conf"
    echo "2. On Windows 11, install WireGuard from: https://www.wireguard.com/install/"
    echo "3. Import the client_windows11.conf file"
    echo "4. Configure Oracle Cloud Security List (see warning above)"
    echo "5. Activate the tunnel"
    echo ""
    log_info "To add more clients, run:"
    echo "  ./wireguard-oracle-setup.sh --add-client <client-name>"
    echo ""
    log_info "To run diagnostics, run:"
    echo "  ./wireguard-oracle-setup.sh --diagnose"
    echo ""
    log_info "To auto-fix issues, run:"
    echo "  ./wireguard-oracle-setup.sh --fix"
}

###############################################################################
# Command-line Arguments
###############################################################################

case "${1:-}" in
    --add-client)
        if [ -z "$2" ]; then
            log_error "Please provide a client name"
            echo "Usage: $0 --add-client <client-name>"
            exit 1
        fi
        detect_network
        generate_keys
        # Find next available IP
        LAST_IP=$(grep "AllowedIPs = 10.8.0" /etc/wireguard/wg0.conf | tail -1 | grep -oP '10\.8\.0\.\K\d+' || echo "1")
        NEXT_IP=$((LAST_IP + 1))
        add_client "$2" "$NEXT_IP"
        systemctl restart wg-quick@wg0
        log_success "Client added. Please download: /etc/wireguard/client_$2.conf"
        ;;
    --diagnose)
        detect_network
        run_diagnostics
        ;;
    --fix)
        detect_network
        auto_fix
        run_diagnostics
        ;;
    --help)
        echo "WireGuard Smart Setup Script"
        echo ""
        echo "Usage:"
        echo "  $0                    - Full installation"
        echo "  $0 --add-client NAME  - Add a new client"
        echo "  $0 --diagnose         - Run diagnostics"
        echo "  $0 --fix              - Auto-fix common issues"
        echo "  $0 --help             - Show this help"
        ;;
    *)
        main
        ;;
esac
