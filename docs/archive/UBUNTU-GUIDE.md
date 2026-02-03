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