# WireGuard Oracle Linux 8 - Complete Setup Package

## 📦 What's Included

This package contains everything you need to set up and troubleshoot WireGuard on Oracle Linux 8 ARM:

1. **wireguard-oracle-setup.sh** - Main installation and setup script
2. **complete-fix.sh** - Comprehensive fix for connection issues
3. **install-dashboard.sh** - Optional web dashboard installer
4. **README.md** - Quick start guide
5. **TROUBLESHOOTING.md** - Detailed troubleshooting guide

## 🎯 The Problem You're Facing

**Symptom:** WireGuard connects on Windows 11, but no internet access.

**Root Cause:** Usually one or more of these issues on Oracle Cloud:
1. Oracle Cloud Security List not configured (90% of cases)
2. iptables NAT rules not persisting
3. IP forwarding disabled
4. firewalld blocking traffic

## ✨ Smart Features of This Solution

### Auto-Detection
- Automatically detects your network interface
- Finds your public IP address
- Identifies configuration issues

### Self-Healing
- Auto-fixes IP forwarding
- Repairs NAT rules
- Configures firewall automatically
- Makes settings persistent across reboots

### Built-in Diagnostics
- Checks all critical settings
- Shows exactly what's wrong
- Provides clear fix instructions

## 🚀 Quick Installation

### Method 1: Automatic (Recommended)

```bash
# 1. Make scripts executable
chmod +x wireguard-oracle-setup.sh complete-fix.sh install-dashboard.sh

# 2. Run the main setup
sudo ./wireguard-oracle-setup.sh

# 3. If you have connection issues, run the fix
sudo ./complete-fix.sh

# 4. (Optional) Install web dashboard
sudo ./install-dashboard.sh
```

### Method 2: Manual Step-by-Step

If you prefer to understand each step:

```bash
# 1. Install WireGuard
sudo dnf install -y oracle-epel-release-el8
sudo dnf install -y wireguard-tools iptables qrencode

# 2. Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf

# 3. Get your network interface
IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
echo "Network interface: $IFACE"

# 4. Configure iptables
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $IFACE -j MASQUERADE
sudo iptables -A FORWARD -i wg0 -j ACCEPT
sudo iptables -A FORWARD -o wg0 -j ACCEPT
sudo iptables -I INPUT -p udp --dport 51820 -j ACCEPT

# 5. Configure firewalld
sudo firewall-cmd --permanent --add-port=51820/udp
sudo firewall-cmd --permanent --zone=public --add-masquerade
sudo firewall-cmd --reload

# 6. Generate server keys
sudo mkdir -p /etc/wireguard
cd /etc/wireguard
sudo wg genkey | sudo tee server_private.key | wg pubkey | sudo tee server_public.key
sudo chmod 600 server_private.key

# 7. Create server config
sudo tee /etc/wireguard/wg0.conf > /dev/null <<EOF
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = $(sudo cat server_private.key)
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $IFACE -j MASQUERADE
MTU = 1420
EOF

# 8. Generate client config (run this as a script)
sudo bash -c "
cd /etc/wireguard
CLIENT_PRIVATE=\$(wg genkey)
CLIENT_PUBLIC=\$(echo \$CLIENT_PRIVATE | wg pubkey)
PRESHARED=\$(wg genpsk)
SERVER_PUBLIC=\$(cat server_public.key)
PUBLIC_IP=\$(curl -s ifconfig.me)

# Add peer to server
cat >> wg0.conf <<EOC

[Peer]
PublicKey = \$CLIENT_PUBLIC
PresharedKey = \$PRESHARED
AllowedIPs = 10.8.0.2/32
EOC

# Create client config
cat > client_windows11.conf <<EOC
[Interface]
PrivateKey = \$CLIENT_PRIVATE
Address = 10.8.0.2/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1420

[Peer]
PublicKey = \$SERVER_PUBLIC
PresharedKey = \$PRESHARED
Endpoint = \$PUBLIC_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOC

chmod 600 client_windows11.conf
"

# 9. Start WireGuard
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

# 10. Make iptables persistent
sudo mkdir -p /etc/iptables
sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

## 🔧 After Installation - Oracle Cloud Configuration

**THIS IS CRITICAL - Most connection issues are here!**

### Configure Security List (Required!)

1. Log into Oracle Cloud Console
2. Go to: **☰ Menu** → **Networking** → **Virtual Cloud Networks**
3. Click your **VCN name**
4. Click **Security Lists** on the left
5. Click **Default Security List for [your-vcn]**
6. Click **Add Ingress Rules**
7. Fill in:
   ```
   Source Type: CIDR
   Source CIDR: 0.0.0.0/0
   IP Protocol: UDP
   Destination Port Range: 51820
   Description: WireGuard VPN
   ```
8. Click **Add Ingress Rules**

**For Dashboard (Optional):**
Repeat steps 6-8 with:
   ```
   IP Protocol: TCP
   Destination Port Range: 8080
   ```

## 📱 Windows 11 Client Setup

1. Download WireGuard: https://www.wireguard.com/install/
2. Install WireGuard for Windows
3. Download your client config from server:
   ```bash
   sudo cat /etc/wireguard/client_windows11.conf
   ```
4. Copy the content and save as `windows11.conf` on your PC
5. Open WireGuard app → **Add Tunnel** → **Import from file**
6. Select `windows11.conf`
7. Click **Activate**

## 🧪 Testing Your Connection

### On Windows (PowerShell):

```powershell
# 1. Check if WireGuard interface is active
ipconfig
# Look for "WireGuard Tunnel" adapter

# 2. Test connection to server
ping 10.8.0.1
# Should respond (if fails: server issue)

# 3. Test internet connectivity
ping 8.8.8.8
# Should respond (if fails: NAT/routing issue)

# 4. Test DNS resolution
nslookup google.com
# Should resolve (if fails: DNS issue)

# 5. Test actual internet
curl https://ifconfig.me
# Should show your server's public IP
```

### On Server:

```bash
# Check if client is connected
sudo wg show

# Should show something like:
# peer: [client-public-key]
#   endpoint: [client-ip]:port
#   allowed ips: 10.8.0.2/32
#   latest handshake: X seconds ago
#   transfer: X.XX KiB received, X.XX KiB sent
```

## 🐛 Common Issues & Solutions

### Issue 1: Can ping 10.8.0.1 but not 8.8.8.8

**Cause:** NAT not working
**Fix:**
```bash
sudo ./complete-fix.sh
```

### Issue 2: Connection timeout / Can't connect at all

**Cause:** Oracle Cloud Security List not configured
**Fix:** Follow the Oracle Cloud Configuration steps above

### Issue 3: Some websites work, others don't

**Cause:** MTU issue
**Fix:** Client config already has `MTU = 1420`, verify it's there

### Issue 4: Slow speeds

**Causes:**
- MTU not optimized (should be 1420)
- Far from server location
- Server overloaded

**Check:**
```bash
# On server
sudo wg show
# Check transfer rates

# On Windows
ping 10.8.0.1
# Check latency (should be < 100ms for good performance)
```

## 📊 Using the Web Dashboard

If you installed the dashboard:

1. Access: `http://YOUR_SERVER_IP:8080`
2. Features:
   - View server status
   - See active connections
   - Add new clients
   - Run diagnostics
   - Auto-fix issues
   - Download client configs

## 🔄 Managing Clients

### Add a New Client

```bash
# Using script
sudo ./wireguard-oracle-setup.sh --add-client laptop

# Or via dashboard
# Go to http://YOUR_SERVER_IP:8080
# Enter client name → Click "Add Client"
```

### Remove a Client

```bash
# 1. Edit server config
sudo nano /etc/wireguard/wg0.conf

# 2. Remove the [Peer] section for that client

# 3. Restart WireGuard
sudo systemctl restart wg-quick@wg0
```

### List All Clients

```bash
# See active connections
sudo wg show

# List all client configs
ls -la /etc/wireguard/client_*.conf
```

## 🔍 Advanced Diagnostics

### Full System Check

```bash
# Run the diagnostic command
sudo ./wireguard-oracle-setup.sh --diagnose

# Or manually:
echo "=== IP Forwarding ==="
sysctl net.ipv4.ip_forward

echo "=== WireGuard Status ==="
sudo systemctl status wg-quick@wg0
sudo wg show

echo "=== NAT Rules ==="
sudo iptables -t nat -L POSTROUTING -n -v

echo "=== Firewall ==="
sudo firewall-cmd --list-all

echo "=== Interface ==="
ip addr show wg0

echo "=== Routing ==="
ip route
```

### Monitor Live Connections

```bash
# Watch WireGuard status in real-time
watch -n 1 sudo wg show

# Monitor traffic on WireGuard interface
sudo tcpdump -i wg0 -n

# View logs
sudo journalctl -u wg-quick@wg0 -f
```

## 🛡️ Security Best Practices

1. **Use strong client names** - Not easily guessable
2. **Rotate keys periodically** - Regenerate client configs every 6 months
3. **Monitor connections** - Check `wg show` regularly
4. **Keep system updated**:
   ```bash
   sudo dnf update
   ```
5. **Backup configs**:
   ```bash
   sudo cp -r /etc/wireguard /root/wireguard-backup
   ```
6. **Consider changing port** - Default 51820 can be scanned
   ```bash
   # In /etc/wireguard/wg0.conf
   ListenPort = 51820  # Change to something like 47854
   ```

## 📁 File Locations Reference

```
/etc/wireguard/
├── wg0.conf                  # Server configuration
├── server_private.key        # Server private key (keep secret!)
├── server_public.key         # Server public key
├── client_windows11.conf     # Client configuration
└── client_*.conf             # Other client configurations

/opt/wireguard-dashboard/     # Dashboard files (if installed)
├── app.py                    # Dashboard application

/etc/iptables/
└── rules.v4                  # Persistent iptables rules

/etc/systemd/system/
├── wg-quick@wg0.service      # WireGuard service
├── iptables-restore.service  # iptables persistence
└── wireguard-dashboard.service  # Dashboard service
```

## 🎓 Understanding the Setup

### Why IP Forwarding?
Allows the server to forward packets between interfaces (wg0 ↔ ens3)

### Why NAT (MASQUERADE)?
Translates private WireGuard IPs (10.8.0.x) to the server's public IP for internet access

### Why PersistentKeepalive?
Keeps NAT mappings alive and prevents connection drops, especially important for Oracle Cloud

### Why MTU 1420?
Accounts for WireGuard encryption overhead (28 bytes) on standard 1500 MTU networks

## 📞 Getting Help

If you're still having issues:

1. **Run diagnostics:**
   ```bash
   sudo ./wireguard-oracle-setup.sh --diagnose
   ```

2. **Try auto-fix:**
   ```bash
   sudo ./complete-fix.sh
   ```

3. **Check logs:**
   ```bash
   sudo journalctl -u wg-quick@wg0 -n 50
   ```

4. **Verify Oracle Cloud Security List** - 90% of issues are here!

5. **Test step by step:**
   - Can you ping 10.8.0.1? → Server accessible
   - Can you ping 8.8.8.8? → Routing works
   - Can you resolve domains? → DNS works

## 🎉 Success Checklist

- [ ] Scripts executed without errors
- [ ] Oracle Cloud Security List configured (UDP 51820)
- [ ] WireGuard service running (`systemctl status wg-quick@wg0`)
- [ ] Can ping 10.8.0.1 from Windows
- [ ] Can ping 8.8.8.8 from Windows
- [ ] Can browse websites through VPN
- [ ] DNS resolution works
- [ ] IP shows server's public IP (check with `curl ifconfig.me`)

## 📝 Quick Reference Commands

```bash
# Start/Stop/Restart WireGuard
sudo systemctl start wg-quick@wg0
sudo systemctl stop wg-quick@wg0
sudo systemctl restart wg-quick@wg0

# Check status
sudo systemctl status wg-quick@wg0
sudo wg show

# View logs
sudo journalctl -u wg-quick@wg0 -f

# Run diagnostics
sudo ./wireguard-oracle-setup.sh --diagnose

# Auto-fix issues
sudo ./complete-fix.sh

# Add client
sudo ./wireguard-oracle-setup.sh --add-client clientname

# Backup configs
sudo tar -czf wireguard-backup.tar.gz /etc/wireguard/
```

Good luck! 🚀
