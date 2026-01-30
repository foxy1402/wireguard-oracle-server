# 🔧 How to Update & Restart Your Existing WireGuard Installation

> **You already have WireGuard installed and working?** This guide is for you!

## ⚡ Quick Update (30 Seconds)

```bash
# 1. Navigate to your installation directory
cd wireguard-oracle-server

# 2. Make scripts executable (one-time)
chmod +x *.sh

# 3. Run the update script
sudo ./update-and-restart.sh
```

**Choose an option:**
1. ✅ **Quick restart** - Just restart WireGuard
2. ✅ **Update + restart** - Update packages then restart
3. ✅ **Complete fix** - Fix internet connectivity issues
4. ✅ **Restart dashboard** - Restart just the dashboard
5. ✅ **Update from GitHub** - Pull latest scripts
6. ✅ **Full check + restart** - **RECOMMENDED** - Check everything and restart all

---

## 🔍 Is Your VPN Actually Working?

Even if the dashboard says "Interface down", your VPN might be working perfectly!

### Quick Check:

```bash
sudo wg show
```

**Look for "latest handshake":**
- `45 seconds ago` = ✅ **ACTIVELY CONNECTED** - Everything is working!
- `3 minutes ago` = ⚠️ **IDLE** - Connected but no recent activity
- `10 minutes ago` = ❌ **DISCONNECTED** - Not actively connected
- (none shown) = ❌ **NEVER CONNECTED** - Client never connected

---

## 📋 Common Tasks

### Restart WireGuard
```bash
sudo systemctl restart wg-quick@wg0
```

### Check Status
```bash
# See who's connected
sudo wg show

# Check service status (should show "active (exited)" - this is CORRECT!)
sudo systemctl status wg-quick@wg0

# Check if interface is up
ip addr show wg0
```

### Add New Client
```bash
sudo ./wireguard-oracle-setup.sh --add-client phone
```

### Fix Internet Issues
```bash
sudo ./complete-fix.sh
```

### Run Health Check
```bash
sudo ./health-check.sh
```

### View Logs
```bash
sudo journalctl -u wg-quick@wg0 -n 50
```

---

## 🔐 Dashboard Issues?

### Issue 1: Dashboard Says "Interface Down" but VPN Works

**This is a FALSE ALARM!** 

**Why:** WireGuard's service shows "active (exited)" which is **NORMAL and CORRECT**. The interface is still running.

**Solution:** 
- Ignore the dashboard warning
- Check `sudo wg show` instead
- If you see recent handshakes, your VPN IS working!

**Read the full explanation:**
```bash
cat DASHBOARD-FIX.md
```

---

### Issue 2: Dashboard Has NO Password! 🚨

**Problem:** The original dashboard has **NO authentication**. Anyone with your server IP can access it!

**Solution:** Install the NEW secure dashboard:

```bash
# Stop old insecure dashboard
sudo systemctl stop wireguard-dashboard
sudo systemctl disable wireguard-dashboard

# Install new secure version
sudo ./install-dashboard-secure.sh

# Access dashboard
# http://YOUR_SERVER_IP:8080
# First visit will ask you to set a password
```

**Features of new dashboard:**
- ✅ Password protection
- ✅ First-time setup screen
- ✅ Session management
- ✅ Logout button
- ✅ Better interface detection
- ✅ Warning about false "down" status

---

### Issue 3: Forgot Dashboard Password?

```bash
# Reset password
sudo rm -f /opt/wireguard-dashboard/password.hash
sudo systemctl restart wireguard-dashboard

# Visit dashboard URL - you'll see password setup screen again
```

---

## 🛡️ Secure Your Dashboard

### Best Practice: Restrict Access by IP

The dashboard should only be accessible from YOUR IP:

**In Oracle Cloud Console:**
1. Go to: ☰ Menu → Networking → VCN → Security Lists
2. Find the rule for **TCP port 8080**
3. Edit the rule
4. Change **Source CIDR** from `0.0.0.0/0` to `YOUR_HOME_IP/32`
5. Get your IP from: https://whatismyip.com

Now only YOUR IP can access the dashboard!

---

## 🧪 Test Your VPN (From Client Device)

### Windows (PowerShell or Command Prompt):
```powershell
# 1. Test VPN server connection
ping 10.8.0.1
# Expected: Replies from 10.8.0.1

# 2. Test internet through VPN
ping 8.8.8.8
# Expected: Replies from 8.8.8.8

# 3. Test DNS
ping google.com
# Expected: Replies with IP addresses

# 4. Verify your IP changed
curl ifconfig.me
# Expected: Shows your Oracle server's IP (not your home IP)
```

### Mac/Linux (Terminal):
```bash
ping 10.8.0.1
ping 8.8.8.8
ping google.com
curl ifconfig.me
```

**If all tests pass:** ✅ VPN is working perfectly!

---

## ❌ Troubleshooting

### Connected but No Internet?

```bash
# Run the fix script
sudo ./complete-fix.sh

# Then disconnect and reconnect your WireGuard client
# Test again: ping 10.8.0.1 then ping 8.8.8.8
```

### Can't Connect at All?

**Check Oracle Cloud Security List:**
1. Log into Oracle Cloud Console
2. Go to: Networking → VCN → Security Lists
3. Verify you have an Ingress Rule:
   - Protocol: UDP
   - Port: 51820
   - Source: 0.0.0.0/0

**Check WireGuard is running:**
```bash
sudo systemctl status wg-quick@wg0
# Should show "active (exited)" <- This is CORRECT!
```

**Check firewall:**
```bash
sudo firewall-cmd --list-ports
# Should show: 51820/udp
```

### Dashboard Won't Load?

**Check if dashboard is running:**
```bash
sudo systemctl status wireguard-dashboard
```

**Check Oracle Cloud Security List for dashboard:**
- Protocol: TCP
- Port: 8080
- Source: 0.0.0.0/0 (or your IP for better security)

**Restart dashboard:**
```bash
sudo systemctl restart wireguard-dashboard
```

---

## 📖 Documentation Files

| File | Purpose |
|------|---------|
| `README.md` | Full installation guide (for new setups) |
| `UPDATE-RESTART.md` | **This file** - For existing installations |
| `AUDIT-RESULTS.md` | What was fixed and why |
| `DASHBOARD-FIX.md` | Dashboard "Interface down" explanation |
| `QUICK-START.md` | Beginner-friendly step-by-step guide |
| `TROUBLESHOOTING.md` | Detailed troubleshooting guide |
| `COMPLETE-GUIDE.md` | Advanced configuration guide |

---

## 📞 Quick Command Reference

```bash
# UPDATE & RESTART
sudo ./update-and-restart.sh

# CHECK STATUS
sudo wg show                           # Active connections
sudo systemctl status wg-quick@wg0     # Service status

# RESTART SERVICES  
sudo systemctl restart wg-quick@wg0          # Restart WireGuard
sudo systemctl restart wireguard-dashboard   # Restart dashboard

# ADD CLIENTS
sudo ./wireguard-oracle-setup.sh --add-client <name>

# FIX ISSUES
sudo ./complete-fix.sh                 # Fix internet issues
sudo ./health-check.sh                 # Run diagnostics

# DASHBOARD
http://YOUR_SERVER_IP:8080            # Access dashboard
sudo rm -f /opt/wireguard-dashboard/password.hash  # Reset password

# LOGS
sudo journalctl -u wg-quick@wg0 -f    # Live logs
sudo journalctl -u wg-quick@wg0 -n 50 # Last 50 entries
```

---

## ✅ Checklist After Update

- [ ] Ran `sudo ./update-and-restart.sh`
- [ ] Checked `sudo wg show` shows recent handshakes
- [ ] Tested `ping 10.8.0.1` from client
- [ ] Tested `ping 8.8.8.8` from client
- [ ] Installed secure dashboard (if using dashboard)
- [ ] Set strong password for dashboard
- [ ] Restricted dashboard access by IP (recommended)
- [ ] Backed up `/etc/wireguard/` directory

---

## 🎯 Understanding "active (exited)"

When you run `sudo systemctl status wg-quick@wg0`, you might see:

```
● wg-quick@wg0.service - WireGuard via wg-quick(8) for wg0
   Loaded: loaded
   Active: active (exited)
```

**This is CORRECT and NORMAL!** ✅

**Why "exited"?**
1. The `wg-quick` script runs
2. It brings up the WireGuard interface
3. It configures routes and firewall
4. **It exits** (because it's done)
5. The interface stays **UP and RUNNING**

**Think of it like this:**
- The script is like a light switch
- You flip it (script runs)
- The light turns on (interface up)
- You let go (script exits)
- The light stays on! (interface still up)

---

## 💡 Pro Tips

### Backup Your Configuration
```bash
# Backup WireGuard configs
sudo tar -czf wireguard-backup-$(date +%Y%m%d).tar.gz /etc/wireguard

# Download to your computer for safekeeping
```

### Monitor Bandwidth
```bash
# See transfer statistics
sudo wg show wg0 transfer
```

### See All Connected Clients
```bash
# Show all peers with handshake times
sudo wg show wg0 latest-handshakes
```

### Remove Old Clients
```bash
# Edit server config
sudo nano /etc/wireguard/wg0.conf

# Delete the [Peer] section for the old client
# Save and exit

# Restart WireGuard
sudo systemctl restart wg-quick@wg0
```

---

## 🔄 Updating Scripts from GitHub

If there are new updates to the repository:

```bash
cd wireguard-oracle-server

# Pull latest changes
git pull

# Make scripts executable
chmod +x *.sh

# Run update script
sudo ./update-and-restart.sh
```

---

## 🆘 Still Need Help?

**Gather diagnostic information:**
```bash
# Run diagnostics
sudo ./wireguard-oracle-setup.sh --diagnose > diagnostics.txt

# Check health
sudo ./health-check.sh > health.txt

# Get WireGuard status
sudo wg show > wg-status.txt

# View files
cat diagnostics.txt
cat health.txt
cat wg-status.txt
```

**Include this information when asking for help:**
- Which step you're stuck on
- Error messages
- Output from commands above
- Client device type (Windows/Mac/Android/iOS)

---

**🎉 That's it! Your WireGuard VPN should be updated and running smoothly!**

**Remember:** If `sudo wg show` displays recent handshakes, your VPN is working correctly even if the dashboard says otherwise! ✅
