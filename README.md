# WireGuard on Oracle Linux 8 - Quick Start Guide

## 🚀 Quick Installation (Recommended)

### Step 1: Upload and Run the Setup Script

```bash
# Download the setup script
wget https://your-server/wireguard-oracle-setup.sh
# OR upload it via SCP/SFTP

# Make it executable
chmod +x wireguard-oracle-setup.sh

# Run the installation (as root)
sudo ./wireguard-oracle-setup.sh
```

This will:
- ✅ Install WireGuard
- ✅ Configure IP forwarding
- ✅ Set up firewall rules
- ✅ Create server configuration
- ✅ Generate a client configuration (windows11.conf)
- ✅ Run diagnostics
- ✅ Auto-fix common issues

### Step 2: Configure Oracle Cloud Security List

**CRITICAL:** This is the #1 reason WireGuard doesn't work!

1. Log into [Oracle Cloud Console](https://cloud.oracle.com)
2. Navigate to: **☰ Menu → Networking → Virtual Cloud Networks**
3. Click your **VCN** → Click **Security Lists** → Click **Default Security List**
4. Click **Add Ingress Rules**
5. Enter:
   - **Source CIDR:** `0.0.0.0/0`
   - **IP Protocol:** `UDP`
   - **Destination Port Range:** `51820`
6. Click **Add Ingress Rules**

### Step 3: Download Client Configuration

```bash
# The client config is at:
/etc/wireguard/client_windows11.conf

# Download it using SCP or copy the content:
sudo cat /etc/wireguard/client_windows11.conf
```

### Step 4: Install WireGuard on Windows 11

1. Download WireGuard from: https://www.wireguard.com/install/
2. Install and open WireGuard
3. Click **Add Tunnel** → **Import from file**
4. Select the `client_windows11.conf` file
5. Click **Activate**

### Step 5: Test Connection

On Windows, open PowerShell:
```powershell
# Check if connected
ping 10.8.0.1

# Test internet
ping 8.8.8.8

# Test DNS
nslookup google.com
```

If you can ping 10.8.0.1 but not 8.8.8.8, run the auto-fix:
```bash
sudo ./wireguard-oracle-setup.sh --fix
```

---

## 🌐 Optional: Install Web Dashboard

For easier management with a nice UI:

```bash
# Make dashboard script executable
chmod +x install-dashboard.sh

# Install the dashboard
sudo ./install-dashboard.sh
```

**Configure Oracle Cloud for dashboard:**
1. Add another Ingress Rule in Security List:
   - **Source CIDR:** `0.0.0.0/0`
   - **IP Protocol:** `TCP`
   - **Destination Port Range:** `8080`

Access dashboard at: `http://YOUR_SERVER_IP:8080`

---

## 📱 Adding More Clients

```bash
# Add a new client (phone, tablet, etc.)
sudo ./wireguard-oracle-setup.sh --add-client myphone

# Download the config
sudo cat /etc/wireguard/client_myphone.conf
```

Or use the web dashboard to add clients with QR codes!

---

## 🔧 Troubleshooting

### Problem: Connected but no internet

**Run auto-fix:**
```bash
sudo ./wireguard-oracle-setup.sh --fix
```

**Run diagnostics:**
```bash
sudo ./wireguard-oracle-setup.sh --diagnose
```

### Problem: Can't connect at all

1. ✅ Check Oracle Cloud Security List (UDP 51820)
2. ✅ Check if WireGuard is running: `sudo systemctl status wg-quick@wg0`
3. ✅ Check firewall: `sudo firewall-cmd --list-ports`

### Problem: Some sites load, others don't

**Fix MTU issue** - Edit client config and add:
```ini
[Interface]
MTU = 1420  # Add this line
```

### Common Commands

```bash
# Check WireGuard status
sudo wg show

# Restart WireGuard
sudo systemctl restart wg-quick@wg0

# View logs
sudo journalctl -u wg-quick@wg0 -f

# Check IP forwarding
sysctl net.ipv4.ip_forward

# Check NAT rules
sudo iptables -t nat -L POSTROUTING -n -v
```

---

## 📋 Complete Verification Checklist

Run these commands to verify everything is working:

```bash
# 1. IP forwarding enabled?
sysctl net.ipv4.ip_forward
# Should show: net.ipv4.ip_forward = 1

# 2. WireGuard running?
sudo systemctl status wg-quick@wg0
# Should show: active (exited)

# 3. NAT rule exists?
sudo iptables -t nat -L POSTROUTING -n | grep MASQUERADE
# Should show a MASQUERADE rule for 10.8.0.0/24

# 4. Firewall allows WireGuard?
sudo firewall-cmd --list-ports
# Should show: 51820/udp

# 5. WireGuard interface up?
ip addr show wg0
# Should show the wg0 interface with IP 10.8.0.1
```

If all checks pass but you still can't connect from Windows:
- ✅ **Double-check Oracle Cloud Security List** (most common issue!)

---

## 🆘 Still Having Issues?

Check the detailed troubleshooting guide:
```bash
cat TROUBLESHOOTING.md
```

Or check the logs:
```bash
# WireGuard logs
sudo journalctl -u wg-quick@wg0 -n 50

# System logs
sudo dmesg | grep -i wireguard
```

---

## 🔐 Security Notes

1. **Keep your private keys secure** - Never share them
2. **Change default port if needed**: Edit `ListenPort` in `/etc/wireguard/wg0.conf`
3. **Use strong client names** - Easy to remember but not predictable
4. **Regularly update**: `sudo dnf update wireguard-tools`
5. **Monitor connections**: `sudo wg show` to see active peers

---

## 📁 Important File Locations

- Server config: `/etc/wireguard/wg0.conf`
- Client configs: `/etc/wireguard/client_*.conf`
- Server keys: `/etc/wireguard/server_*.key`
- Logs: `journalctl -u wg-quick@wg0`

---

## 🎯 Performance Tips

1. **Use PersistentKeepalive**: Already set to 25 seconds in client config
2. **Optimize MTU**: Set to 1420 in both server and client configs
3. **Use Cloudflare DNS**: 1.1.1.1 is fast and private
4. **Close unused connections**: Remove old clients from server config

---

## 📞 Support

If you need help:
1. Run diagnostics: `sudo ./wireguard-oracle-setup.sh --diagnose`
2. Check TROUBLESHOOTING.md
3. Review Oracle Cloud Security List configuration
4. Check server logs: `sudo journalctl -u wg-quick@wg0 -f`

Remember: **Oracle Cloud Security List is the #1 cause of connection issues!**
