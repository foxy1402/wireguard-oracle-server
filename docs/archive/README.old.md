# WireGuard on Oracle Linux 8 - Complete Setup Guide

> **🎯 The Solution to: "WireGuard connects but NO internet!"**  
> This guide solves the most frustrating Oracle Cloud + WireGuard issue with automated scripts.

## ⚡ 30-Second Quick Start

```bash
# 1. On your Oracle instance
git clone https://github.com/foxy1402/wireguard-oracle-server.git
cd wireguard-oracle-server
chmod +x *.sh
sudo ./wireguard-oracle-setup.sh

# 2. In Oracle Cloud Console
# Add Security Rule: UDP Port 51820 from 0.0.0.0/0

# 3. Download client config from server
sudo cat /etc/wireguard/client_windows11.conf
# Copy to your computer and import to WireGuard app

# Done! Connect and test: ping 10.8.0.1 then ping 8.8.8.8
```

**Still have issues?** Run: `sudo ./complete-fix.sh` then reconnect.

**Brand new to this?** 📄 **[Read the step-by-step QUICK-START.md guide](./QUICK-START.md)** - A printable checklist with every single step explained!

---

## 📖 What This Does

Setting up WireGuard on Oracle Cloud is challenging because:
- ❌ Oracle Cloud has special firewall rules that block internet access by default
- ❌ Standard WireGuard guides don't work on Oracle Linux
- ❌ Manual configuration is complex and error-prone

**This repository provides:**
- ✅ **Automated installation** - One command to set everything up
- ✅ **Modern web dashboard** - Manage clients with QR codes and real-time monitoring
- ✅ **Auto-fix script** - Automatically solves the "no internet" problem
- ✅ **Health checks** - Verify everything is working correctly
- ✅ **Oracle Cloud specific** - Designed specifically for Oracle Linux 8 ARM instances
- ✅ **Zero-downtime management** - Add/remove clients without disconnecting others

### ✨ Recent Improvements (Latest Version)

**Dashboard Enhancements:**
- 📱 **QR Code Modal** - Click to display QR codes in elegant overlay (no pop-ups)
- 📊 **Transfer Statistics** - Real-time upload/download data for each client
- 🔄 **Smart Config Reload** - Uses `wg syncconf` to preserve active connections
- ✅ **Accurate Status Detection** - Shows true online/offline based on handshake activity
- 🎨 **Clean Interface** - Removed broken emojis, professional appearance

**Bug Fixes:**
- Fixed Python 3.6 compatibility issues on Oracle Linux 8
- Fixed client status always showing "offline" despite being connected
- Fixed public key matching between config and active connections
- Fixed stats reset when adding/deleting clients
- Fixed handshake times not displaying correctly

### 🔄 How It Works (Visual Overview)

```
Your Device                Oracle Cloud              Internet
    │                           │                        │
    │  1. WireGuard Tunnel      │                        │
    │ ════════════════════════> │                        │
    │     (UDP Port 51820)       │                        │
    │                            │                        │
    │  2. Traffic forwarding     │  3. NAT & Routing     │
    │                            │ ═══════════════════> │
    │                            │   (Your Oracle IP)     │
    │                            │                        │
    │  4. Response returns       │  5. Back through VPN  │
    │ <═══════════════════════════════════════════════ │
    │                            │                        │
   YOU                    YOUR VPN SERVER          GOOGLE.COM
```

**The Challenge:** Steps 2-3 require special Oracle Cloud configuration (firewall + NAT).  
**The Solution:** This repository automates everything with `wireguard-oracle-setup.sh` + `complete-fix.sh`.

---

## 🚀 Quick Start (3 Steps)

### Prerequisites
- Oracle Cloud account with a Linux 8 ARM instance running
- SSH access to your Oracle instance
- WireGuard client on your device ([Download here](https://www.wireguard.com/install/))

---

### **STEP 1: Upload Scripts to Your Server**

**Option A: Using Git (Easiest)**
```bash
# SSH into your Oracle instance, then run:
sudo dnf install -y git
git clone https://github.com/foxy1402/wireguard-oracle-server.git
cd wireguard-oracle-server
```

**Option B: Manual Upload**
1. Download this repository as ZIP from GitHub
2. Extract the files on your computer
3. Use WinSCP, FileZilla, or `scp` to upload all files to your Oracle instance
4. SSH into your server and navigate to the uploaded folder

---

### **STEP 2: Run the Installation Script**

```bash
# Make scripts executable
chmod +x wireguard-oracle-setup.sh complete-fix.sh health-check.sh

# Run the main installation (takes 2-3 minutes)
sudo ./wireguard-oracle-setup.sh
```

**What happens:**
- ✅ Installs WireGuard automatically
- ✅ Configures networking and firewall
- ✅ Generates encryption keys
- ✅ Creates your first client config file (`client_windows11.conf`)
- ✅ Shows you a QR code for easy mobile setup
- ✅ Runs diagnostics and auto-fixes common issues

💡 **Important:** Write down the path shown at the end (usually `/etc/wireguard/client_windows11.conf`)

---

### **STEP 3: Configure Oracle Cloud Firewall** 

⚠️ **CRITICAL - DON'T SKIP THIS!** This is why 90% of people fail.

Oracle Cloud blocks all traffic by default. You MUST add a firewall rule:

1. **Login** to [Oracle Cloud Console](https://cloud.oracle.com)
2. **Click** the hamburger menu (☰) → **Networking** → **Virtual Cloud Networks**
3. **Click** on your VCN name (e.g., "vcn-...")
4. On the left sidebar, **click** "Security Lists"
5. **Click** on "Default Security List for vcn-..."
6. **Click** the blue button **"Add Ingress Rules"**
7. **Fill in:**
   - **Source CIDR:** `0.0.0.0/0` (allows connection from anywhere)
   - **IP Protocol:** `UDP` (WireGuard uses UDP)
   - **Destination Port Range:** `51820` (WireGuard default port)
   - Leave other fields as default
8. **Click** "Add Ingress Rules" button at the bottom

✅ **Verification:** You should see a new rule in the list with UDP port 51820

---

### **STEP 4: Download Your Client Configuration**

**Option A: Copy-paste method (Easier for beginners)**
```bash
# On your server, display the config file:
sudo cat /etc/wireguard/client_windows11.conf
```
1. Select and copy ALL the text that appears
2. On your Windows/Mac computer, open Notepad/TextEdit
3. Paste the text
4. Save the file as `wireguard.conf` (make sure it's .conf, not .txt)

**Option B: Direct download (Advanced users)**
```bash
# From your computer (not the server), run:
scp your-username@your-server-ip:/etc/wireguard/client_windows11.conf ./wireguard.conf
```
Replace `your-username` and `your-server-ip` with your actual details.

**Option C: For mobile devices (Easiest!)**
- A QR code was displayed during installation
- Open your WireGuard mobile app and scan the QR code
- Done! Skip to Step 6 for mobile.

---

### **STEP 5: Import Configuration to WireGuard Client**

**For Windows:**
1. Download and install WireGuard from: https://www.wireguard.com/install/
2. Open the WireGuard application
3. Click **"Add Tunnel"** button (or drag and drop your .conf file)
4. Click **"Import tunnel(s) from file"**
5. Select the `wireguard.conf` file you saved in Step 4
6. You should see a new tunnel named "windows11" or "wireguard"

**For Mac:**
1. Install WireGuard from the App Store
2. Click the WireGuard menu bar icon → **"Import Tunnel(s) from File"**
3. Select your `.conf` file

**For Mobile (Android/iOS):**
1. Install WireGuard from Play Store / App Store
2. Tap the **+** button → **"Scan from QR code"**
3. Scan the QR code shown during server installation (or generate a new one - see section below)

---

### **STEP 6: Connect and Test**

**To Connect:**
1. In the WireGuard app, find your tunnel (e.g., "windows11")
2. Click the **"Activate"** button or toggle switch
3. Status should change to **"Active"**

**Testing Your Connection:**

On **Windows**, open PowerShell or Command Prompt and run:
```powershell
# Test 1: Can you reach the WireGuard server?
ping 10.8.0.1
# Should get replies ✅

# Test 2: Can you access the internet?
ping 8.8.8.8
# Should get replies ✅

# Test 3: Is DNS working?
ping google.com
# Should get replies ✅
```

On **Mac/Linux**, open Terminal and run the same ping commands above.

On **Mobile**, open a web browser and try visiting any website.

**✅ If all tests pass:** Congratulations! Your VPN is working! You can now optionally install the web dashboard (see next section) or skip to troubleshooting if needed.

---

## 🌐 OPTIONAL: Install Web Dashboard (After Main Setup)

**⚠️ Only do this AFTER completing Steps 1-6 above and confirming your VPN works!**

The web dashboard makes it easy to manage WireGuard clients through a web browser instead of command line.

### When to Install Dashboard

Install the dashboard if you want:
- ✅ Easy client management with a graphical interface
- ✅ QR codes generated automatically for mobile devices
- ✅ Real-time view of connected clients
- ✅ Bandwidth usage monitoring

**Skip this if:** You're comfortable using command line for client management.

---

### Dashboard Installation (3 Simple Steps)

#### **STEP 1: Install Dashboard on Server**

SSH into your Oracle instance and run:
```bash
chmod +x install-dashboard.sh
sudo ./install-dashboard.sh
```

Wait 1-2 minutes for installation to complete.

---

#### **STEP 2: Open Firewall Port in Oracle Cloud Console**

**⚠️ CRITICAL - The dashboard won't be accessible without this!**

1. **Login** to Oracle Cloud Console: https://cloud.oracle.com

2. **Navigate** to the firewall settings:
   - Click the **☰ hamburger menu** (top left)
   - Click **Networking**
   - Click **Virtual Cloud Networks**

3. **Select your VCN:**
   - Click on your VCN name (e.g., "vcn-20250130-...")

4. **Go to Security Lists:**
   - On the left sidebar, click **Security Lists**
   - Click **Default Security List for vcn-...**

5. **Add Ingress Rule** for the dashboard:
   - Click the blue **Add Ingress Rules** button
   - Fill in the form:
     - **Source Type:** CIDR
     - **Source CIDR:** `0.0.0.0/0` (allows access from anywhere)
     - **IP Protocol:** TCP
     - **Destination Port Range:** `8080`
     - **Description:** WireGuard Dashboard
   - Click **Add Ingress Rules** at the bottom

6. **Verify the rule was added:**
   - You should see a new rule: TCP, port 8080, source 0.0.0.0/0

✅ **Firewall is now configured!**

---

#### **STEP 3: Access Dashboard and Set Password**

1. **Find your server's public IP:**
   ```bash
   curl ifconfig.me
   ```

2. **Open your web browser** and visit:
   ```
   http://YOUR_SERVER_IP:8080
   ```
   (Replace YOUR_SERVER_IP with the IP from step 1)

3. **First-time setup** (only on first visit):
   - You'll see a "Set Password" screen
   - Enter a strong password (at least 8 characters)
   - Confirm the password
   - Click "Set Password"
   - ✅ Your password is now saved on the server

4. **Login:**
   - Use the password you just created
   - You should now see the dashboard!

5. **Start managing clients:**
   - Click "Add Client" to add new devices
   - Scan QR codes with mobile app
   - Download configs for desktop
   - See who's connected in real-time

---

### Dashboard Features

The modern web dashboard provides a clean, intuitive interface with these features:

**Client Management:**
- ✅ **Add clients** - Automatically generates configs with encryption keys
- ✅ **QR code display** - Click QR button to show scannable code in modal overlay
- ✅ **Download configs** - One-click download for desktop clients
- ✅ **Delete clients** - Remove old devices safely (preserves other connections)

**Real-time Monitoring:**
- ✅ **Connection status** - See online/offline status for each client
- ✅ **Last handshake** - View connection timestamps (e.g., "2 minutes ago")
- ✅ **Transfer statistics** - Monitor upload/download data per client
- ✅ **Auto-refresh** - Dashboard updates every 10-30 seconds automatically

**Server Diagnostics:**
- ✅ **Server status** - Check if WireGuard service is running
- ✅ **IP forwarding** - Verify kernel forwarding is enabled
- ✅ **NAT rules** - Confirm MASQUERADE is configured
- ✅ **Firewall status** - Check if ports are open
- ✅ **Auto-fix button** - One-click repair for common issues

**Technical Improvements (Latest Version):**
- ✅ **Zero-downtime updates** - Adding/deleting clients doesn't disconnect others
- ✅ **Preserved statistics** - Transfer stats and handshake times stay intact
- ✅ **Python 3.6 compatible** - Works on Oracle Linux 8 default Python
- ✅ **Clean UI** - No broken emojis, professional appearance
- ✅ **Modal QR codes** - In-page overlay instead of pop-up windows

---

### Forgot Dashboard Password?

If you forget your dashboard password, SSH into your server and run:

```bash
# Remove the password file to reset
sudo rm -f /opt/wireguard-dashboard/password.hash
sudo systemctl restart wireguard-dashboard
# Visit the dashboard URL - you'll see the password setup screen again
```

---

### Securing Your Dashboard (Recommended)

After installing, improve security:

1. **Restrict access by IP** (Highly recommended):
   - Go back to Oracle Cloud Console → Security Lists
   - Edit the port 8080 rule
   - Change **Source CIDR** from `0.0.0.0/0` to `YOUR_HOME_IP/32`
   - Get your IP from: https://whatismyip.com
   - This allows only YOUR IP to access the dashboard

2. **Use a strong password:**
   - At least 12 characters
   - Mix of uppercase, lowercase, numbers, symbols
   - Store in a password manager

3. **Change password regularly:**
   ```bash
   cd /opt/wireguard-dashboard
   sudo ./reset-password.sh
   ```

---

## 🔧 Troubleshooting

### 🔍 Quick Diagnostic Flowchart

**Start here:**
```
Can you connect to WireGuard at all?
│
├─ NO → Problem 2 (Cannot Connect)
│
└─ YES → Can you ping 10.8.0.1?
    │
    ├─ NO → Check client config, restart WireGuard
    │
    └─ YES → Can you ping 8.8.8.8?
        │
        ├─ NO → Problem 1 (No Internet) ⭐ MOST COMMON
        │
        └─ YES → Can you access websites?
            │
            ├─ NO → Problem 3 (DNS/MTU Issue)
            │
            └─ YES → 🎉 Everything works!
```

### ❌ Problem 1: Connected but NO Internet Access

**Symptom:** `ping 10.8.0.1` works ✅, but `ping 8.8.8.8` fails ❌

**Solution:** Run the complete fix script on your server:
```bash
sudo ./complete-fix.sh
```

This will:
- Re-enable IP forwarding
- Fix NAT/iptables rules
- Configure Oracle Cloud specific firewall rules
- Make all changes permanent (survive reboots)

After running, disconnect and reconnect your WireGuard client, then test again.

---

### ❌ Problem 2: Cannot Connect at All

**Symptom:** WireGuard shows "Connecting..." forever or immediate failure

**Common causes and fixes:**

**✅ Check #1: Oracle Cloud Security List**
- This is the #1 reason! Go back to Step 3 and verify you added the UDP 51820 rule
- Make sure the rule shows "0.0.0.0/0" as source, not something else

**✅ Check #2: Is WireGuard running on the server?**
```bash
sudo systemctl status wg-quick@wg0
# Should show "active (exited)" in green
```
If not running:
```bash
sudo systemctl restart wg-quick@wg0
```

**✅ Check #3: Firewall on server**
```bash
sudo firewall-cmd --list-ports
# Should show: 51820/udp
```
If not listed:
```bash
sudo firewall-cmd --permanent --add-port=51820/udp
sudo firewall-cmd --reload
```

**✅ Check #4: Wrong server IP in client config?**
- Open your WireGuard client config
- Check the `Endpoint` line - it should have your Oracle instance's PUBLIC IP
- Get your public IP: `curl ifconfig.me`

---

### ❌ Problem 3: Some Websites Work, Others Don't

**Symptom:** Can access Google but other sites fail, or downloads break

**Solution:** MTU (packet size) issue

1. **Edit your client config** in WireGuard app
2. Find the `[Interface]` section
3. Add this line (or change if it exists):
   ```ini
   MTU = 1420
   ```
4. Save and reconnect

---

### ❌ Problem 4: Connection Drops After a While

**Symptom:** Works for a few minutes then stops

**Solution:** NAT keepalive issue (should already be configured, but verify)

1. **Edit your client config**
2. Find the `[Peer]` section
3. Make sure this line exists:
   ```ini
   PersistentKeepalive = 25
   ```
4. Save and reconnect

---

### 🔍 Run Health Check

To see exactly what's wrong:
```bash
# Run the health check script
sudo ./health-check.sh
```

This will check:
- ✅ WireGuard installation
- ✅ IP forwarding
- ✅ Firewall rules
- ✅ NAT configuration
- ✅ Active connections

It will tell you exactly what needs fixing.

---

### 🛠️ Useful Commands

```bash
# Check WireGuard status
sudo wg show

# View WireGuard logs
sudo journalctl -u wg-quick@wg0 -f

# Restart WireGuard
sudo systemctl restart wg-quick@wg0

# Check IP forwarding
sysctl net.ipv4.ip_forward
# Should show: net.ipv4.ip_forward = 1

# Check NAT rules
sudo iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE
# Should show a rule for 10.8.0.0/24

# Run auto-fix
sudo ./wireguard-oracle-setup.sh --fix

# Run diagnostics
sudo ./wireguard-oracle-setup.sh --diagnose
```

---

## 📱 Adding More Devices (Phone, Tablet, Laptop)

### Method 1: Using the Script (Recommended)

```bash
# Add a new client (replace 'myphone' with any name you want)
sudo ./wireguard-oracle-setup.sh --add-client myphone

# The script will:
# - Generate keys for the new device
# - Create a config file
# - Display a QR code
# - Show you the config file location

# To see the config again:
sudo cat /etc/wireguard/client_myphone.conf

# To generate a QR code again:
sudo qrencode -t ansiutf8 < /etc/wireguard/client_myphone.conf
```

### Method 2: Using Web Dashboard (If Installed)

If you installed the optional web dashboard:
- Login to dashboard at `http://YOUR_SERVER_IP:8080`
- Click "Add Client"
- Enter device name
- Scan QR code or download config

---

## 🔐 Security Best Practices

### Essential Security Tips

1. **🔑 Protect Your Private Keys**
   - Never share `/etc/wireguard/server_private.key`
   - Client configs contain private keys - treat them like passwords
   - Don't share client configs between devices

2. **🚪 Change Default Port (Optional)**
   If you want to use a different port than 51820:
   ```bash
   # Edit server config
   sudo nano /etc/wireguard/wg0.conf
   # Change ListenPort = 51820 to your desired port
   
   # Update firewall
   sudo firewall-cmd --permanent --add-port=YOUR_PORT/udp
   sudo firewall-cmd --reload
   
   # Restart WireGuard
   sudo systemctl restart wg-quick@wg0
   ```
   ⚠️ Don't forget to update Oracle Cloud Security List with the new port!

3. **🗑️ Remove Unused Clients**
   ```bash
   # Edit server config
   sudo nano /etc/wireguard/wg0.conf
   # Delete the [Peer] section for the old client
   
   # Restart WireGuard
   sudo systemctl restart wg-quick@wg0
   ```

4. **🔄 Keep System Updated**
   ```bash
   # Update WireGuard and system packages monthly
   sudo dnf update -y
   ```

5. **👀 Monitor Active Connections**
   ```bash
   # See who's currently connected
   sudo wg show
   ```

6. **🛡️ Secure Dashboard Access (If Installed)**
   
   **Strong Password:**
   - Use at least 12 characters
   - Mix of uppercase, lowercase, numbers, symbols
   - Store in a password manager
   - Change every 3-6 months: `sudo ./reset-password.sh`
   
   **Restrict by IP:**
   ```bash
   # Update Oracle Cloud Security List for port 8080:
   # Change Source CIDR from 0.0.0.0/0 to YOUR_HOME_IP/32
   # This allows only your IP to access the dashboard
   ```
   
   **Use HTTPS:**
   - Install SSL certificate for encrypted dashboard access
   - Prevents password interception on public networks

7. **💾 Backup Your Configuration**
   ```bash
   # Backup WireGuard configs and dashboard data
   sudo tar -czf wireguard-backup.tar.gz /etc/wireguard /opt/wireguard-dashboard
   # Download to your computer for safekeeping
   ```

---

## 📋 Complete Verification Checklist

Use this checklist to verify everything is working correctly:

### Server-Side Checks (Run on Oracle instance)

```bash
# ✅ Check 1: IP forwarding enabled?
sysctl net.ipv4.ip_forward
# Expected: net.ipv4.ip_forward = 1

# ✅ Check 2: WireGuard running?
sudo systemctl status wg-quick@wg0
# Expected: "active (exited)" in green

# ✅ Check 3: NAT rule exists?
sudo iptables -t nat -L POSTROUTING -n | grep MASQUERADE
# Expected: A line showing "10.8.0.0/24" and "MASQUERADE"

# ✅ Check 4: Firewall allows WireGuard?
sudo firewall-cmd --list-ports
# Expected: Should include "51820/udp"

# ✅ Check 5: WireGuard interface up?
ip addr show wg0
# Expected: Should show interface with IP 10.8.0.1/24

# ✅ Check 6: Oracle Cloud Security List configured?
# Log into Oracle Cloud Console and verify UDP 51820 ingress rule exists
```

### Client-Side Checks (Run on your device)

**Windows PowerShell / Mac Terminal / Linux Terminal:**
```bash
# ✅ Test 1: Can reach VPN server?
ping 10.8.0.1
# Expected: Replies from 10.8.0.1

# ✅ Test 2: Internet access through VPN?
ping 8.8.8.8
# Expected: Replies from 8.8.8.8

# ✅ Test 3: DNS resolution working?
ping google.com
# Expected: Replies showing IP addresses

# ✅ Test 4: Check your public IP changed
curl ifconfig.me
# Expected: Should show your Oracle server's IP, not your home IP
```

**If all tests pass:** 🎉 **Congratulations! Your WireGuard VPN is working perfectly!**

**If any test fails:** 📖 See the Troubleshooting section above.

---

## 📁 Important File Locations

**Server Files (on Oracle instance):**
- **Server config:** `/etc/wireguard/wg0.conf` - Main WireGuard server configuration
- **Client configs:** `/etc/wireguard/client_*.conf` - Generated client configuration files
- **Server keys:** `/etc/wireguard/server_*.key` - Server's private and public keys (keep secure!)
- **iptables rules:** `/etc/iptables/rules.v4` - Saved firewall rules
- **Logs:** View with `journalctl -u wg-quick@wg0`

**What Each File Contains:**
- `wg0.conf` = Server settings + list of allowed clients
- `client_*.conf` = Everything a client needs to connect (keys, server IP, DNS, etc.)
- `server_private.key` = ⚠️ **NEVER SHARE THIS** - Server's secret key

---

## 🎯 Performance Tips

### Optimize Your VPN Connection

1. **✅ Enable Persistent Keepalive (Already configured)**
   - Keeps connection alive through NAT
   - Set to 25 seconds in all client configs
   - Prevents connection drops

2. **✅ Use Optimal MTU (Already configured)**
   - Set to 1420 in both server and client
   - Prevents packet fragmentation
   - Improves stability and speed

3. **🚀 Use Fast DNS Servers**
   Already configured in client configs:
   - Primary: `1.1.1.1` (Cloudflare - fast and private)
   - Secondary: `8.8.8.8` (Google - reliable)
   
   To change: Edit `DNS =` line in your client config

4. **📊 Monitor Bandwidth**
   ```bash
   # See transfer statistics
   sudo wg show wg0 transfer
   ```

5. **🧹 Remove Inactive Clients**
   - Fewer configured clients = better performance
   - Remove old devices you don't use anymore
   - Edit `/etc/wireguard/wg0.conf` and delete unused `[Peer]` sections

6. **⚡ Oracle Cloud Instance Performance**
   - Free tier ARM instances are quite fast!
   - Upgrade to paid tier for even better performance
   - Consider choosing a region closer to your location

---

## 🆘 Getting Help

### Self-Help Resources (Try these first!)

1. **Run the health check:**
   ```bash
   sudo ./health-check.sh
   ```
   This will tell you exactly what's wrong.

2. **Run the complete fix:**
   ```bash
   sudo ./complete-fix.sh
   ```
   Automatically fixes most common issues.

3. **Check the detailed troubleshooting guide:**
   ```bash
   cat TROUBLESHOOTING.md
   ```
   Contains solutions for specific error messages.

4. **View WireGuard logs:**
   ```bash
   # Live logs (watch in real-time)
   sudo journalctl -u wg-quick@wg0 -f
   
   # Last 50 log entries
   sudo journalctl -u wg-quick@wg0 -n 50
   
   # Logs with errors only
   sudo journalctl -u wg-quick@wg0 -p err
   ```

### Still Stuck?

**Before asking for help, gather this information:**

```bash
# Run diagnostics and save output
sudo ./wireguard-oracle-setup.sh --diagnose > diagnostics.txt

# Check your setup
sudo ./health-check.sh > health.txt

# Get WireGuard status
sudo wg show > wg-status.txt
```

Include this information when asking for help:
1. Which step you're stuck on
2. Error messages you're seeing
3. Output from the commands above
4. Your Oracle Cloud region
5. Client device type (Windows/Mac/Android/iOS)

### Common Questions

**Q: Can I use this for multiple people?**  
A: Yes! Add a client for each person using `--add-client`. Each gets their own config file.

**Q: Will this work on Oracle Cloud Free Tier?**  
A: Yes! This guide is specifically designed for Oracle Cloud Free Tier ARM instances.

**Q: Does this work on other Oracle Linux versions?**  
A: This is optimized for Oracle Linux 8 ARM. It may work on other versions but hasn't been tested.

**Q: Can I use a different port instead of 51820?**  
A: Yes! See the "Security Best Practices" section for instructions.

**Q: How do I backup my configuration?**  
A: Copy these files to a safe location:
```bash
sudo cp -r /etc/wireguard ~/wireguard-backup
# Then download the backup folder to your computer
```

**Q: What if my Oracle instance restarts?**  
A: Everything is configured to start automatically on boot. WireGuard will be running when the server comes back up.

**Q: Can I connect multiple devices at the same time?**  
A: Yes! Each device needs its own client config (create with `--add-client`), then all can connect simultaneously.

**Q: How do I check if someone is using my VPN right now?**  
A:
```bash
sudo wg show
# Look for "latest handshake" - if recent (< 3 minutes), they're connected
```

**Q: Does this hide my IP address?**  
A: Yes! When connected, websites see your Oracle server's IP instead of your real IP.

**Q: I forgot my dashboard password. How do I reset it?**  
A: SSH into your server and run:
```bash
cd /opt/wireguard-dashboard
sudo ./reset-password.sh
```
Or manually remove the password file and restart the dashboard:
```bash
sudo systemctl stop wg-dashboard
sudo rm -f /opt/wireguard-dashboard/db/users.db
sudo systemctl restart wg-dashboard
```
Visit the dashboard URL again - you'll see the password setup screen.

**Q: Where is my dashboard password stored?**  
A: The password is hashed and securely stored on your Oracle instance, typically at:
- `/opt/wireguard-dashboard/db/users.db` or
- `/etc/wireguard-dashboard/password.hash`

The password never leaves your server and persists across reboots.

**Q: Can I change my dashboard password without resetting it?**  
A: Most dashboards have a "Change Password" option in settings. Alternatively, use the reset method above to set a new password.

---

## 📊 What Makes This Different?

### Why This Solution Works (When Others Don't)

**Problem with standard WireGuard guides:**
- ❌ They don't account for Oracle Cloud's unique firewall setup
- ❌ NAT rules don't persist after reboot on Oracle Linux
- ❌ No auto-detection of network interfaces
- ❌ Missing Oracle Cloud Security List configuration
- ❌ No troubleshooting tools

**What this repository includes:**
- ✅ **Auto-detects** your network configuration
- ✅ **Oracle-specific** firewall rules that persist
- ✅ **Automated fixes** for the "no internet" problem
- ✅ **Health checks** to verify everything works
- ✅ **Step-by-step** Oracle Cloud Console instructions
- ✅ **QR codes** for easy mobile setup
- ✅ **Complete logs** for troubleshooting

---

## 🔄 Updating This Installation

To update the scripts to the latest version:

```bash
cd wireguard-oracle-server
git pull

# Re-run if you want to update server config
sudo ./wireguard-oracle-setup.sh --fix
```

**Note:** This won't affect your existing client configurations or keys.

---

## 🙏 Credits & License

This repository is designed to help people successfully set up WireGuard on Oracle Cloud without frustration.

**Key Technologies:**
- [WireGuard](https://www.wireguard.com/) - Fast, modern VPN protocol
- [Oracle Cloud](https://www.oracle.com/cloud/) - Free tier ARM instances
- Oracle Linux 8 - Stable enterprise Linux distribution

**Contributing:**
Found a bug or have an improvement? Feel free to open an issue or pull request on GitHub!

**Repository:** https://github.com/foxy1402/wireguard-oracle-server

---

## 📝 Quick Reference Card

**Save this for quick access:**

| Task | Command |
|------|---------|
| **Add new client** | `sudo ./wireguard-oracle-setup.sh --add-client NAME` |
| **Check status** | `sudo wg show` |
| **Restart WireGuard** | `sudo systemctl restart wg-quick@wg0` |
| **View logs** | `sudo journalctl -u wg-quick@wg0 -f` |
| **Fix problems** | `sudo ./complete-fix.sh` |
| **Health check** | `sudo ./health-check.sh` |
| **Run diagnostics** | `sudo ./wireguard-oracle-setup.sh --diagnose` |
| **See client config** | `sudo cat /etc/wireguard/client_NAME.conf` |
| **Show QR code** | `sudo qrencode -t ansiutf8 < /etc/wireguard/client_NAME.conf` |
| **Reset dashboard password** | `cd /opt/wireguard-dashboard && sudo ./reset-password.sh` |
| **Restart dashboard** | `sudo systemctl restart wg-dashboard` |
| **Check dashboard status** | `sudo systemctl status wg-dashboard` |

**Oracle Cloud Console Quick Link:**  
🔗 https://cloud.oracle.com → Networking → Virtual Cloud Networks → Your VCN → Security Lists

**WireGuard Download:**  
🔗 https://www.wireguard.com/install/

**Dashboard Access:**  
🔗 http://YOUR_SERVER_IP:8080 (first visit sets up password)

---

**🎉 That's it! You now have a fully functional WireGuard VPN on Oracle Cloud!**

Remember:
- Oracle Cloud Security List is the #1 cause of issues - double-check it!
- Use `complete-fix.sh` if you have internet connection problems
- Run `health-check.sh` to verify everything is working

**Happy secure browsing! 🔒**
