# WireGuard on Oracle Linux 8 - Complete Guide

> **🎯 Comprehensive guide for setting up WireGuard VPN on Oracle Cloud with Oracle Linux 8**

## Table of Contents
- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Step-by-Step Installation](#step-by-step-installation)
- [Oracle Cloud Firewall Configuration](#oracle-cloud-firewall-configuration)
- [Client Setup](#client-setup)
- [Testing Your VPN](#testing-your-vpn)
- [Management Commands](#management-commands)
- [Web Dashboard](#web-dashboard)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

---

## Quick Start

**For experienced users - 3 commands:**

```bash
git clone https://github.com/yourusername/wireguard-oracle-server.git
cd wireguard-oracle-server
chmod +x *.sh && sudo ./wireguard-oracle-setup.sh
```

Then configure Oracle Cloud Security List (UDP port 51820) and you're done!

**For beginners:** Follow the detailed steps below ⬇️

---

## Prerequisites

### What You Need

✅ **Oracle Cloud Account** - [Sign up free](https://www.oracle.com/cloud/free/)  
✅ **Oracle Linux 8 Instance** - Free tier VM.Standard.A1.Flex works perfectly  
✅ **SSH Access** - Ability to connect to your instance  
✅ **WireGuard Client** - [Download for your device](https://www.wireguard.com/install/)

### Instance Specifications (Recommended)

| Component | Specification |
|-----------|--------------|
| **OS** | Oracle Linux 8 ARM |
| **Shape** | VM.Standard.A1.Flex (4 OCPUs, 24GB RAM - free tier) |
| **Boot Volume** | 50-100 GB |
| **Network** | Public IP address assigned |

---

## Step-by-Step Installation

### Step 1: Create Oracle Linux Instance

1. **Login** to Oracle Cloud Console: https://cloud.oracle.com
2. **Navigate** to Compute → Instances → Create Instance
3. **Configure:**
   - **Name:** wireguard-vpn-server
   - **Image:** Oracle Linux 8 (ARM or AMD64)
   - **Shape:** VM.Standard.A1.Flex
   - **OCPUs:** 4 (up to 4 free on ARM)
   - **Memory:** 24 GB (up to 24 GB free on ARM)
4. **SSH Keys:** Upload your public key or generate new
5. Click **"Create"** and wait 2-3 minutes
6. **Note** your instance's **Public IP Address**

### Step 2: Connect to Your Instance

```bash
# From your computer (Mac/Linux/Windows WSL):
ssh opc@YOUR_INSTANCE_IP

# If using custom SSH key:
ssh -i /path/to/your/key.pem opc@YOUR_INSTANCE_IP
```

**Note:** Default username is `opc` (Oracle Public Cloud)

### Step 3: Download Setup Scripts

```bash
# Install git
sudo dnf install -y git

# Clone repository
git clone https://github.com/yourusername/wireguard-oracle-server.git
cd wireguard-oracle-server

# Make scripts executable
chmod +x *.sh
```

### Step 4: Run Installation Script

```bash
sudo ./wireguard-oracle-setup.sh
```

**What happens (takes 2-3 minutes):**
- ✅ Installs WireGuard from EPEL repository
- ✅ Configures IP forwarding
- ✅ Sets up firewalld rules
- ✅ Configures iptables NAT
- ✅ Generates encryption keys
- ✅ Creates server and client configs
- ✅ Shows QR code for easy mobile setup
- ✅ Runs diagnostics and auto-fixes issues

**Expected output:**
```
[SUCCESS] WireGuard installation completed!
Client configuration file: /etc/wireguard/client_windows11.conf
```

---

## Oracle Cloud Firewall Configuration

⚠️ **CRITICAL STEP** - This is why 90% of users fail!

Oracle Cloud blocks UDP port 51820 by default. You MUST configure the Security List.

### Configure Security List

1. **Login** to Oracle Cloud Console
2. **Navigate:**  
   ☰ Menu → Networking → Virtual Cloud Networks
3. **Click** your VCN name
4. **Click** "Security Lists" (left sidebar)
5. **Click** "Default Security List for vcn-..."
6. **Click** blue "Add Ingress Rules" button
7. **Fill in:**
   ```
   Source Type: CIDR
   Source CIDR: 0.0.0.0/0
   IP Protocol: UDP
   Destination Port Range: 51820
   Description: WireGuard VPN
   ```
8. **Click** "Add Ingress Rules"

✅ **Verify:** You should now see the rule in the list

**Without this step, clients cannot connect!**

---

## Client Setup

### Get Your Client Configuration

```bash
# Display the config
sudo cat /etc/wireguard/client_windows11.conf
```

**Copy all the text** - it should look like this:
```ini
[Interface]
PrivateKey = <your-private-key>
Address = 10.8.0.2/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1420

[Peer]
PublicKey = <server-public-key>
PresharedKey = <preshared-key>
Endpoint = YOUR_SERVER_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

### Install WireGuard Client

**Windows:**
1. Download from https://www.wireguard.com/install/
2. Install WireGuard
3. Click "Add Tunnel" → "Add empty tunnel..."
4. Paste your config
5. Click "Save" and "Activate"

**macOS:**
1. Install from App Store
2. Import config file or paste content
3. Activate tunnel

**Mobile (iOS/Android):**
1. Install WireGuard from App/Play Store
2. **Easy way:** Scan QR code shown during server setup
3. **Manual way:** Create tunnel from file/text
4. Activate tunnel

---

## Testing Your VPN

Once connected, run these tests on your client device:

### Test 1: Can you reach the VPN server?
```bash
ping 10.8.0.1
```
**Expected:** Replies from 10.8.0.1 ✅

### Test 2: Can you access the internet?
```bash
ping 8.8.8.8
```
**Expected:** Replies from 8.8.8.8 ✅

### Test 3: Is DNS working?
```bash
ping google.com
```
**Expected:** Replies from Google's IP ✅

### Test 4: Check your public IP
```bash
curl ifconfig.me
```
**Expected:** Shows your Oracle instance IP ✅

**All tests pass?** 🎉 **Congratulations! Your VPN works!**

---

## Management Commands

### Add More Clients

```bash
sudo ./wireguard-oracle-setup.sh --add-client myphone

# View the new config
sudo cat /etc/wireguard/client_myphone.conf

# Show QR code
sudo qrencode -t ansiutf8 < /etc/wireguard/client_myphone.conf
```

### Check WireGuard Status

```bash
# View active connections
sudo wg show

# Check service status
sudo systemctl status wg-quick@wg0

# View logs
sudo journalctl -u wg-quick@wg0 -f
```

### Restart WireGuard

```bash
sudo systemctl restart wg-quick@wg0
```

### Run Health Check

```bash
sudo ./health-check.sh
```

### Auto-Fix Common Issues

```bash
sudo ./complete-fix.sh
```

### Run Full Diagnostics

```bash
sudo ./wireguard-oracle-setup.sh --diagnose
```

---

## Web Dashboard

Manage your VPN with a beautiful web interface!

### Install Dashboard

```bash
sudo ./install-dashboard.sh
```

### Access Dashboard

1. Open browser: `http://YOUR_SERVER_IP:8080`
2. **First visit:** Set a strong password
3. **Login** with your password
4. Start managing clients!

### Configure Firewall for Dashboard

**Option 1: Allow from anywhere**
```bash
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

**Option 2: Allow from specific IP only (more secure)**
```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="YOUR_HOME_IP" port protocol="tcp" port="8080" accept'
sudo firewall-cmd --reload
```

### Dashboard Features

- 📊 Real-time server status
- 👥 Add/delete clients instantly
- 📱 Generate QR codes
- 💾 Download client configs
- 📈 View traffic statistics
- 🔧 Auto-fix button
- 🔄 Auto-refresh every 30 seconds

### Dashboard Commands

```bash
# Check dashboard status
sudo systemctl status wireguard-dashboard

# View logs
sudo journalctl -u wireguard-dashboard -f

# Restart dashboard
sudo systemctl restart wireguard-dashboard

# Stop dashboard
sudo systemctl stop wireguard-dashboard
```

---

## Troubleshooting

### Issue 1: Can ping 10.8.0.1 but NOT 8.8.8.8

**This is the #1 most common problem!**

**Cause:** NAT/routing not configured properly

**Fix:**
```bash
sudo ./complete-fix.sh
```

Then disconnect and reconnect your VPN.

**Manual fix:**
```bash
# Check IP forwarding
sudo sysctl net.ipv4.ip_forward
# Should show: net.ipv4.ip_forward = 1

# If not enabled
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf

# Check NAT rules
sudo iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE

# If missing, add it
INTERFACE=$(ip route | grep default | awk '{print $5}')
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $INTERFACE -j MASQUERADE

# Make persistent
sudo firewall-cmd --permanent --add-masquerade
sudo firewall-cmd --reload
```

---

### Issue 2: Cannot Connect at All

**Checklist:**

1. **Oracle Cloud Security List configured?**
   - Go back to [Oracle Cloud Firewall Configuration](#oracle-cloud-firewall-configuration)
   - Verify UDP port 51820 rule exists

2. **WireGuard service running?**
   ```bash
   sudo systemctl status wg-quick@wg0
   # Should show "active (exited)" in green
   ```

3. **Firewall allows port?**
   ```bash
   sudo firewall-cmd --list-all
   # Should show: ports: 51820/udp
   ```

4. **Can you reach the server at all?**
   ```bash
   # From your computer
   ping YOUR_SERVER_IP
   ```

---

### Issue 3: Connection Drops Frequently

**Cause:** NAT timeout or keepalive issues

**Fix in client config:**
```ini
[Peer]
PersistentKeepalive = 15  # Reduce from 25 to 15
```

---

### Issue 4: Slow Speed

**Possible causes:**
1. MTU too large
2. Oracle free tier bandwidth limits
3. Geographic distance

**Try reducing MTU:**
```ini
[Interface]
MTU = 1280  # Reduce from 1420
```

---

### Issue 5: DNS Not Working

**Symptoms:** Can ping IPs but can't resolve domain names

**Fix in client config:**
```ini
[Interface]
DNS = 1.1.1.1, 8.8.8.8  # Add or change this line
```

**Alternative DNS servers:**
- Google: `8.8.8.8, 8.8.4.4`
- Cloudflare: `1.1.1.1, 1.0.0.1`
- Quad9: `9.9.9.9, 149.112.112.112`

---

### Issue 6: Port 51820 Already in Use

**Check what's using the port:**
```bash
sudo ss -ulnp | grep 51820
```

**Change WireGuard port:**
```bash
sudo nano /etc/wireguard/wg0.conf
# Change: ListenPort = 51820 to another port (e.g., 51821)

# Update firewall
sudo firewall-cmd --permanent --remove-port=51820/udp
sudo firewall-cmd --permanent --add-port=51821/udp
sudo firewall-cmd --reload

# Update Oracle Cloud Security List too!

# Restart WireGuard
sudo systemctl restart wg-quick@wg0
```

---

### Diagnostic Commands

```bash
# Full health check
sudo ./health-check.sh

# Check IP forwarding
sudo sysctl net.ipv4.ip_forward

# Check NAT rules
sudo iptables -t nat -L POSTROUTING -n -v

# Check firewalld
sudo firewall-cmd --list-all

# Check WireGuard interface
ip addr show wg0

# Check active connections
sudo wg show

# View system logs
sudo journalctl -u wg-quick@wg0 -n 50

# Check routing
ip route show table all
```

---

## Advanced Configuration

### Custom VPN Subnet

Edit `/etc/wireguard/wg0.conf`:
```ini
[Interface]
Address = 10.9.0.1/24  # Change from 10.8.0.0/24
```

Update clients accordingly.

### Split Tunneling

To only route specific traffic through VPN (not all traffic):

**Client config:**
```ini
[Peer]
AllowedIPs = 10.8.0.0/24  # Only VPN subnet, not 0.0.0.0/0
```

### Multiple Ports

To run WireGuard on multiple ports:
```bash
# Copy config
sudo cp /etc/wireguard/wg0.conf /etc/wireguard/wg1.conf

# Edit new config
sudo nano /etc/wireguard/wg1.conf
# Change: ListenPort = 51821
# Change: Address = 10.9.0.1/24

# Enable new interface
sudo systemctl enable --now wg-quick@wg1
```

### IPv6 Support

Add to server config:
```ini
[Interface]
Address = 10.8.0.1/24, fd00::1/64
```

Update client configs with IPv6 addresses.

---

## File Locations

```
/etc/wireguard/
├── wg0.conf                  # Server configuration
├── server_private.key        # Server private key (keep secret!)
├── server_public.key         # Server public key
├── client_windows11.conf     # First client config
└── client_*.conf             # Other client configs

/opt/wireguard-dashboard/     # Dashboard files (if installed)
├── app.py                    # Dashboard application
├── password.hash             # Hashed dashboard password
└── session.key               # Session token

/etc/systemd/system/
├── wg-quick@wg0.service      # WireGuard service
└── wireguard-dashboard.service  # Dashboard service (if installed)
```

---

## Security Best Practices

1. **Protect private keys:**
   ```bash
   sudo chmod 600 /etc/wireguard/server_private.key
   sudo chmod 600 /etc/wireguard/wg0.conf
   ```

2. **Use strong dashboard password** (if using web interface)

3. **Limit dashboard access:**
   ```bash
   # Only allow from your IP
   sudo firewall-cmd --permanent --remove-port=8080/tcp
   sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="YOUR_IP" port protocol="tcp" port="8080" accept'
   sudo firewall-cmd --reload
   ```

4. **Keep system updated:**
   ```bash
   sudo dnf update -y
   ```

5. **Monitor connections:**
   ```bash
   sudo wg show
   ```

6. **Backup configs:**
   ```bash
   sudo tar -czf wireguard-backup.tar.gz /etc/wireguard/
   ```

---

## Performance Tuning

### Optimize for High Traffic

Add to `/etc/sysctl.conf`:
```bash
# Increase network buffers
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Enable TCP Fast Open
net.ipv4.tcp_fastopen = 3

# Apply
sudo sysctl -p
```

### Monitor Performance

```bash
# Check bandwidth usage
sudo iftop -i wg0

# Monitor connections
watch -n 1 'sudo wg show'

# System resources
htop
```

---

## Updating

To update WireGuard:
```bash
sudo dnf update wireguard-tools
sudo systemctl restart wg-quick@wg0
```

To update scripts:
```bash
cd wireguard-oracle-server
git pull
chmod +x *.sh
```

---

## Uninstallation

To completely remove WireGuard:
```bash
# Stop service
sudo systemctl stop wg-quick@wg0
sudo systemctl disable wg-quick@wg0

# Remove packages
sudo dnf remove wireguard-tools

# Remove configs (CAUTION: This deletes all configs!)
sudo rm -rf /etc/wireguard/

# Remove firewall rules
sudo firewall-cmd --permanent --remove-port=51820/udp
sudo firewall-cmd --permanent --remove-masquerade
sudo firewall-cmd --reload

# Remove iptables rules (manually check)
sudo iptables -t nat -L POSTROUTING -n --line-numbers
# Then delete specific rule numbers
```

---

## Getting Help

1. **Run health check:**
   ```bash
   sudo ./health-check.sh
   ```

2. **Run auto-fix:**
   ```bash
   sudo ./complete-fix.sh
   ```

3. **Check logs:**
   ```bash
   sudo journalctl -u wg-quick@wg0 -n 100
   ```

4. **Verify Oracle Cloud Security List** - 90% of issues stem from this!

5. **Open GitHub Issue:** Include health check output

---

**Made with ❤️ for Oracle Cloud Free Tier users**
