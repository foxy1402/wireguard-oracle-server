# WireGuard on Ubuntu - Complete Guide

> **🎯 Comprehensive guide for Ubuntu 20.04, 22.04, and 24.04 (including Minimal)**  
> Works perfectly on Oracle Cloud Free Tier

## Table of Contents
- [Quick Start](#quick-start)
- [Why Ubuntu?](#why-ubuntu)
- [Prerequisites](#prerequisites)
- [Step-by-Step Installation](#step-by-step-installation)
- [Oracle Cloud Firewall](#oracle-cloud-firewall-configuration)
- [Client Setup](#client-setup)
- [Testing Your VPN](#testing-your-vpn)
- [Management Commands](#management-commands)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

---

# WireGuard on Ubuntu - Complete Setup Guide

> **🎯 Optimized for Ubuntu 20.04, 22.04, and 24.04**  
> Works on: Canonical Ubuntu, Ubuntu Minimal, Ubuntu Minimal aarch64

## ⚡ 30-Second Quick Start
```bash
# 1. On your Ubuntu instance
git clone https://github.com/yourusername/wireguard-oracle-server.git
cd wireguard-oracle-server
chmod +x ubuntu-*.sh wireguard-ubuntu-setup.sh
sudo ./wireguard-ubuntu-setup.sh

# 2. In Oracle Cloud Console
# Add Security Rule: UDP Port 51820 from 0.0.0.0/0

# 3. Download client config from server
sudo cat /etc/wireguard/client_ubuntu_client.conf
# Copy to your computer and import to WireGuard app

# Done! Connect and test: ping 10.8.0.1 then ping 8.8.8.8
```

**Still have issues?** Run: `sudo ./ubuntu-complete-fix.sh` then reconnect.

---

## 📖 Why Ubuntu Instead of Oracle Linux?

### Advantages of Ubuntu for WireGuard:

✅ **WireGuard built into kernel** (Ubuntu 20.04+) - No EPEL needed  
✅ **Simpler package management** - `apt` is faster than `dnf`  
✅ **Better firewall** - `ufw` is easier than `firewalld`  
✅ **More stable** - Larger community, better tested  
✅ **Less RAM usage** - ~150MB less than Oracle Linux 8  
✅ **Faster boot** - ~10-15 seconds vs 20-30 seconds  
✅ **LTS support** - Ubuntu 22.04 supported until 2027, Ubuntu 24.04 until 2029

### Supported Ubuntu Versions:

| Version | Codename | Kernel | WireGuard Support | Status |
|---------|----------|--------|-------------------|---------|
| 24.04 LTS | Noble Numbat | 6.8+ | ✅ Built-in | Recommended |
| 22.04 LTS | Jammy Jellyfish | 5.15+ | ✅ Built-in | Recommended |
| 20.04 LTS | Focal Fossa | 5.4+ | ✅ Built-in | Supported |
| 18.04 LTS | Bionic Beaver | 4.15 | ⚠️ Requires backport | Not recommended |

### Performance on Oracle Cloud Free Tier:

| Metric | Ubuntu 22.04 Minimal | Oracle Linux 8 |
|--------|---------------------|----------------|
| Base RAM | ~150-200 MB | ~300-400 MB |
| WireGuard install | 1 command | 3+ commands |
| Boot time | ~10-15 sec | ~20-30 sec |
| Package updates | Fast | Slower |

---

## 🚀 Complete Installation Guide

### Prerequisites

- Oracle Cloud account
- Ubuntu instance (20.04/22.04/24.04) on Oracle Cloud
- SSH access to your instance
- WireGuard client on your device

---

### **STEP 1: Create Ubuntu Instance on Oracle Cloud**

1. **Login** to Oracle Cloud Console: https://cloud.oracle.com
2. **Navigate** to Compute → Instances
3. Click **"Create Instance"**
4. **Configure:**
   - **Name:** wireguard-vpn-server
   - **Image:** **Canonical Ubuntu 22.04 Minimal aarch64** ⭐ RECOMMENDED
   - **Shape:** VM.Standard.A1.Flex
   - **OCPUs:** 1 (or up to 4 for free tier)
   - **Memory:** 6 GB (or up to 24 GB for free tier)
   - **Boot Volume:** 50 GB
5. **SSH Keys:** Upload your public key or generate new pair
6. Click **"Create"**
7. **Wait** 2-3 minutes for instance to provision
8. **Note** your instance's **Public IP Address**

---

### **STEP 2: Connect to Your Ubuntu Instance**
```bash
# From your computer (Mac/Linux/Windows with WSL):
ssh ubuntu@YOUR_INSTANCE_IP

# If using custom SSH key:
ssh -i /path/to/your/key.pem ubuntu@YOUR_INSTANCE_IP
```

**Note:** Default username is `ubuntu` (not `opc` like Oracle Linux)

---

### **STEP 3: Download and Run Setup Script**
```bash
# Update package lists
sudo apt update

# Install git
sudo apt install -y git

# Clone repository
git clone https://github.com/yourusername/wireguard-oracle-server.git
cd wireguard-oracle-server

# Make Ubuntu scripts executable
chmod +x wireguard-ubuntu-setup.sh ubuntu-complete-fix.sh ubuntu-health-check.sh

# Run the installation (takes 2-3 minutes)
sudo ./wireguard-ubuntu-setup.sh
```

**What happens:**
- ✅ Installs WireGuard from Ubuntu repos
- ✅ Configures IP forwarding
- ✅ Sets up UFW + iptables firewall
- ✅ Generates encryption keys
- ✅ Creates server config
- ✅ Creates your first client config (`client_ubuntu_client.conf`)
- ✅ Shows QR code for mobile setup
- ✅ Runs diagnostics and auto-fixes issues

---

### **STEP 4: Configure Oracle Cloud Firewall**

⚠️ **CRITICAL - This is why 90% of people fail!**

1. **Login** to Oracle Cloud Console
2. **Navigate:** ☰ Menu → Networking → Virtual Cloud Networks
3. **Click** your VCN name
4. **Click** "Security Lists" (left sidebar)
5. **Click** "Default Security List for vcn-..."
6. **Click** blue "Add Ingress Rules" button
7. **Fill in:**
   - Source CIDR: `0.0.0.0/0`
   - IP Protocol: `UDP`
   - Destination Port Range: `51820`
   - Description: `WireGuard VPN`
8. **Click** "Add Ingress Rules"

✅ **Verify:** You should see UDP port 51820 in the rules list

---

### **STEP 5: Download Client Configuration**
```bash
# Display client config
sudo cat /etc/wireguard/client_ubuntu_client.conf
```

**Copy** all the text and save as `wireguard.conf` on your computer.

**For mobile:** A QR code was displayed during installation - scan it with the WireGuard app!

---

### **STEP 6: Install WireGuard Client**

**Windows:**
1. Download: https://www.wireguard.com/install/
2. Install WireGuard
3. Click "Add Tunnel" → "Import from file"
4. Select your `wireguard.conf`
5. Click "Activate"

**Mac:**
1. Install from App Store
2. Import `wireguard.conf`
3. Activate

**Mobile:**
1. Install from Play Store / App Store
2. Scan QR code shown during setup
3. Activate

---

### **STEP 7: Test Your Connection**

**On your device, run:**
```bash
# Test 1: Can you reach the VPN server?
ping 10.8.0.1
# Expected: Replies ✅

# Test 2: Can you access the internet?
ping 8.8.8.8
# Expected: Replies ✅

# Test 3: Is DNS working?
ping google.com
# Expected: Replies ✅
```

**✅ If all tests pass:** Congratulations! Your VPN works!

---

## 🔧 Troubleshooting

### ❌ Problem 1: Can ping 10.8.0.1 but NOT 8.8.8.8

**This is the most common issue!**

**Solution:**
```bash
sudo ./ubuntu-complete-fix.sh
```

Then disconnect and reconnect your VPN.

---

### ❌ Problem 2: Cannot Connect at All

**Check #1: Oracle Cloud Security List**
- Go back to Step 4
- Verify UDP port 51820 rule exists
- Source should be `0.0.0.0/0`

**Check #2: WireGuard running?**
```bash
sudo systemctl status wg-quick@wg0
# Should show "active (exited)" in green
```

**Check #3: Firewall on server**
```bash
sudo ufw status
# Should show: 51820/udp ALLOW Anywhere
```

---

### 🔍 Run Health Check
```bash
sudo ./ubuntu-health-check.sh
```

This checks:
- ✅ WireGuard installation
- ✅ IP forwarding
- ✅ Firewall rules
- ✅ NAT configuration
- ✅ Active connections

---

## 📱 Add More Devices
```bash
# Add a new client
sudo ./wireguard-ubuntu-setup.sh --add-client myphone

# View the config
sudo cat /etc/wireguard/client_myphone.conf

# Show QR code again
sudo qrencode -t ansiutf8 < /etc/wireguard/client_myphone.conf
```

---

## 🛠️ Useful Commands
```bash
# Check WireGuard status
sudo wg show

# View logs
sudo journalctl -u wg-quick@wg0 -f

# Restart WireGuard
sudo systemctl restart wg-quick@wg0

# Check IP forwarding
sysctl net.ipv4.ip_forward
# Should show: = 1

# Check NAT rules
sudo iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE

# Check UFW status
sudo ufw status verbose

# Run diagnostics
sudo ./wireguard-ubuntu-setup.sh --diagnose

# Auto-fix issues
sudo ./wireguard-ubuntu-setup.sh --fix
```

---

## 🔐 Security Best Practices

1. **Protect private keys:**
```bash
   # Server private key (NEVER share!)
   sudo chmod 600 /etc/wireguard/server_private.key
```

2. **Change default port (optional):**
```bash
   sudo nano /etc/wireguard/wg0.conf
   # Change: ListenPort = 51820 to another port
   
   # Update firewall
   sudo ufw allow YOUR_PORT/udp
   sudo ufw delete allow 51820/udp
   
   # Update Oracle Cloud Security List!
```

3. **Keep system updated:**
```bash
   sudo apt update && sudo apt upgrade -y
```

4. **Monitor connections:**
```bash
   sudo wg show
```

5. **Backup configs:**
```bash
   sudo tar -czf wireguard-backup.tar.gz /etc/wireguard/
```

---

## 📊 Ubuntu vs Oracle Linux Comparison

| Feature | Ubuntu 22.04 Minimal | Oracle Linux 8 |
|---------|---------------------|----------------|
| **Installation** | 1 command | 3+ commands + EPEL |
| **Package Manager** | apt (fast) | dnf (slower) |
| **Firewall** | ufw (simple) | firewalld (complex) |
| **RAM Usage** | ~200 MB | ~350 MB |
| **Boot Time** | 10-15 sec | 20-30 sec |
| **Persistence** | netfilter-persistent | Custom systemd |
| **Community** | Huge | Small |
| **Documentation** | Excellent | Limited |

**Winner:** Ubuntu 22.04 Minimal ⭐

---

## 📁 File Locations
```
/etc/wireguard/
├── wg0.conf                     # Server configuration
├── server_private.key           # Server private key (keep secret!)
├── server_public.key            # Server public key
├── client_ubuntu_client.conf    # First client config
└── client_*.conf                # Other client configs

/etc/iptables/
└── rules.v4                     # Persistent iptables rules

/etc/systemd/system/
└── wg-quick@wg0.service         # WireGuard service
```

---

## 🎯 Success Checklist

- [ ] Ubuntu instance created and SSH accessible
- [ ] Scripts downloaded and executed without errors
- [ ] Oracle Cloud Security List configured (UDP 51820)
- [ ] WireGuard service running (`systemctl status wg-quick@wg0`)
- [ ] Can ping 10.8.0.1 from client
- [ ] Can ping 8.8.8.8 from client
- [ ] Websites load through VPN
- [ ] DNS resolution works
- [ ] Public IP shows server IP (`curl ifconfig.me`)

---

## 💡 Pro Tips

- **Faster setup:** Ubuntu Minimal boots 2x faster than Oracle Linux
- **Less RAM:** Ubuntu uses 40% less RAM - more room for other apps
- **Better support:** Ubuntu has 10x more community tutorials
- **LTS stability:** Ubuntu 22.04 supported until 2027
- **QR codes:** Mobile setup takes 30 seconds with QR scanning
- **Auto-start:** WireGuard starts automatically on reboot

---

## 🆘 Getting Help

1. **Run health check:**
```bash
   sudo ./ubuntu-health-check.sh
```

2. **Run auto-fix:**
```bash
   sudo ./ubuntu-complete-fix.sh
```

3. **Check logs:**
```bash
   sudo journalctl -u wg-quick@wg0 -n 50
```

4. **Verify Oracle Cloud Security List** - 90% of issues!

---

## 📝 Quick Reference

| Task | Command |
|------|---------|
| Add client | `sudo ./wireguard-ubuntu-setup.sh --add-client NAME` |
| Check status | `sudo wg show` |
| Restart | `sudo systemctl restart wg-quick@wg0` |
| View logs | `sudo journalctl -u wg-quick@wg0 -f` |
| Fix issues | `sudo ./ubuntu-complete-fix.sh` |
| Health check | `sudo ./ubuntu-health-check.sh` |
| Diagnostics | `sudo ./wireguard-ubuntu-setup.sh --diagnose` |
| Show QR | `sudo qrencode -t ansiutf8 < /etc/wireguard/client_NAME.conf` |

---

**🎉 Congratulations! You now have a high-performance WireGuard VPN on Ubuntu!**

**Happy secure browsing! 🔒**

---

# Troubleshooting

# WireGuard on Ubuntu - Troubleshooting Guide

## Quick Diagnosis

Run these commands first to identify the problem:
```bash
# Quick health check
sudo ./ubuntu-health-check.sh

# Check if WireGuard is running
sudo systemctl status wg-quick@wg0

# Check active connections
sudo wg show

# Check firewall rules
sudo iptables -t nat -L POSTROUTING -n -v
```

---

## Common Issues & Solutions

### Issue 1: Oracle Cloud Security List Not Configured

**Symptoms:** Client connects but no internet access

**Fix:**
1. Log into Oracle Cloud Console
2. Go to: ☰ Menu → Networking → Virtual Cloud Networks
3. Click your VCN → Security Lists → Default Security List
4. Click "Add Ingress Rules"
5. Add:
   - Source CIDR: `0.0.0.0/0`
   - IP Protocol: `UDP`
   - Destination Port Range: `51820`
6. Click "Add Ingress Rules"

---

### Issue 2: iptables NAT Rules Not Working

**Diagnosis:**
```bash
sudo iptables -t nat -L POSTROUTING -n -v
# Should show MASQUERADE rule for 10.8.0.0/24
```

**Fix:**
```bash
# Get network interface
IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

# Add NAT rule
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $IFACE -j MASQUERADE

# Make persistent
sudo apt-get install -y iptables-persistent netfilter-persistent
sudo mkdir -p /etc/iptables
sudo iptables-save > /etc/iptables/rules.v4
sudo systemctl enable netfilter-persistent
```

---

### Issue 3: IP Forwarding Not Enabled

**Diagnosis:**
```bash
sysctl net.ipv4.ip_forward
# Should return: net.ipv4.ip_forward = 1
```

**Fix:**
```bash
# Enable immediately
sudo sysctl -w net.ipv4.ip_forward=1

# Make permanent
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

---

### Issue 4: UFW Blocking Traffic

**Diagnosis:**
```bash
sudo ufw status verbose
```

**Fix:**
```bash
# Allow SSH (important!)
sudo ufw allow 22/tcp

# Allow WireGuard
sudo ufw allow 51820/udp

# Enable UFW
sudo ufw enable
```

---

### Issue 5: MTU Issues

**Symptoms:** Some websites load, others don't

**Fix in Client Config:**
```ini
[Interface]
PrivateKey = <your-key>
Address = 10.8.0.2/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1420  # Add this line
```

---

### Issue 6: DNS Not Working

**Symptoms:** Can ping IPs but can't resolve domain names

**Fix:**
```ini
[Interface]
PrivateKey = <your-key>
Address = 10.8.0.2/24
DNS = 1.1.1.1, 8.8.8.8  # Add or change this line
```

**Alternative DNS:**
- Google: `8.8.8.8, 8.8.4.4`
- Cloudflare: `1.1.1.1, 1.0.0.1`
- Quad9: `9.9.9.9, 149.112.112.112`

---

## Diagnostic Commands

### Check WireGuard Status
```bash
sudo systemctl status wg-quick@wg0
sudo wg show
ip addr show wg0
```

### Check Network
```bash
# Routing
ip route

# Forwarding
sudo iptables -L FORWARD -v -n

# NAT
sudo iptables -t nat -L -n -v
```

### Check Firewall
```bash
# UFW
sudo ufw status verbose

# iptables
sudo iptables -L -n -v
```

---

## Complete Fix Script

If nothing else works:
```bash
sudo ./ubuntu-complete-fix.sh
```

---

## Verification Checklist

- [ ] IP forwarding enabled (`sysctl net.ipv4.ip_forward` = 1)
- [ ] WireGuard running (`systemctl status wg-quick@wg0`)
- [ ] NAT rule exists (`iptables -t nat -L POSTROUTING`)
- [ ] UFW allows port 51820 (`ufw status`)
- [ ] Oracle Cloud Security List allows UDP 51820
- [ ] Can ping 10.8.0.1
- [ ] Can ping 8.8.8.8
- [ ] DNS works (`nslookup google.com`)

---

---

## Issue 7: WireGuard Service Fails to Start

**Symptoms:** `systemctl status wg-quick@wg0` shows failed

**Diagnosis:**
```bash
# View detailed errors
sudo journalctl -xeu wg-quick@wg0

# Check config syntax
sudo wg-quick up wg0
```

**Common Causes:**
1. **Invalid private key format**
2. **Incorrect interface name in PostUp/PostDown**
3. **Permission issues on config file**

**Fix:**
```bash
# Check config permissions
sudo chmod 600 /etc/wireguard/wg0.conf

# Verify keys
sudo cat /etc/wireguard/server_private.key | wg pubkey
# Should output a valid public key

# Test config manually
sudo wg-quick up wg0
```

---

## Issue 8: Kernel Module Not Loading

**Symptoms:** `lsmod | grep wireguard` returns nothing

**For Ubuntu 20.04+:** WireGuard should be built-in

**Fix:**
```bash
# Try loading manually
sudo modprobe wireguard

# If fails, check kernel version
uname -r
# Should be 5.4+ for Ubuntu 20.04, 5.15+ for 22.04

# If kernel is too old, update
sudo apt update
sudo apt upgrade -y linux-generic
sudo reboot
```

---

## Issue 9: Port Already in Use

**Symptoms:** Cannot start WireGuard, port 51820 busy

**Diagnosis:**
```bash
# Check what's using the port
sudo ss -ulnp | grep 51820
```

**Fix:**
```bash
# Stop conflicting service
sudo systemctl stop <service-name>

# Or change WireGuard port
sudo nano /etc/wireguard/wg0.conf
# Change: ListenPort = 51820 to ListenPort = 51821

# Update firewall
sudo ufw delete allow 51820/udp
sudo ufw allow 51821/udp

# Update Oracle Cloud Security List!
```

---

## Issue 10: Client Config QR Code Not Showing

**Symptoms:** QR code not displayed during setup

**Fix:**
```bash
# Install qrencode
sudo apt install -y qrencode

# Generate QR code manually
sudo qrencode -t ansiutf8 < /etc/wireguard/client_ubuntu_client.conf

# For specific client
sudo qrencode -t ansiutf8 < /etc/wireguard/client_YOURNAME.conf
```

---

## Advanced Troubleshooting

### Check Routing Table
```bash
# View routing table
ip route show table all

# Should show WireGuard subnet
# 10.8.0.0/24 dev wg0 scope link
```

### Check Interface Status
```bash
# Detailed interface info
ip -details addr show wg0

# Should show:
# - inet 10.8.0.1/24
# - state UP
```

### Test NAT Traversal
```bash
# From client, trace route
traceroute -n 8.8.8.8

# Should show:
# 1  10.8.0.1 (WireGuard server)
# 2  <Oracle gateway>
# 3  <external network>
```

### Capture Traffic (Debug)
```bash
# Install tcpdump
sudo apt install -y tcpdump

# Monitor WireGuard traffic
sudo tcpdump -i wg0 -n

# Monitor UDP port 51820
sudo tcpdump -i any -n udp port 51820
```

---

## Getting Help

### Step 1: Run Diagnostics
```bash
# Run health check
sudo ./ubuntu-health-check.sh

# Run full diagnostics
sudo ./wireguard-ubuntu-setup.sh --diagnose
```

### Step 2: Collect Logs
```bash
# WireGuard service logs
sudo journalctl -u wg-quick@wg0 -n 100 --no-pager

# Kernel logs for WireGuard
sudo dmesg | grep -i wireguard

# System logs
sudo tail -n 50 /var/log/syslog
```

### Step 3: Try Auto-Fix
```bash
# Run complete fix
sudo ./ubuntu-complete-fix.sh

# Then test again
sudo ./ubuntu-health-check.sh
```

### Step 4: Manual Reset (Last Resort)
```bash
# Stop WireGuard
sudo systemctl stop wg-quick@wg0

# Remove interface
sudo ip link delete wg0

# Backup configs
sudo cp -r /etc/wireguard /etc/wireguard.backup

# Restart setup
sudo ./wireguard-ubuntu-setup.sh
```

---

## Architecture-Specific Issues

### ARM64 (aarch64) on Oracle Free Tier

**Issue:** Some tools may not be pre-installed

**Fix:**
```bash
# Install essential tools
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r)
```

### x86_64 (AMD64)

**Issue:** Generally more compatible, fewer issues

**Note:** No special fixes needed

---

## Performance Optimization

### Reduce Latency
```ini
# In client config, reduce keepalive
[Peer]
PersistentKeepalive = 15  # Instead of 25
```

### Increase Throughput
```ini
# In server config /etc/wireguard/wg0.conf
[Interface]
MTU = 1500  # Increase from 1420 if no fragmentation
```

### Test Performance
```bash
# From client, test speed
curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -
```

---

## Still Having Issues?

1. ✅ Verify Oracle Cloud Security List (most common issue)
2. ✅ Check `/etc/wireguard/wg0.conf` syntax
3. ✅ Ensure IP forwarding is enabled
4. ✅ Verify NAT masquerade rule exists
5. ✅ Check kernel version (5.4+ for Ubuntu 20.04)
6. ✅ Review logs: `sudo journalctl -u wg-quick@wg0`

**If all else fails:** Start fresh with `sudo ./wireguard-ubuntu-setup.sh`
