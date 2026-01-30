# 🔧 Dashboard "WireGuard Interface Down" Fix

## Problem

The WireGuard dashboard shows "WireGuard Interface down" even though:
- ✅ You have a working `.conf` file
- ✅ Internet connection works when connected
- ✅ `sudo wg show` displays active connections

## Why This Happens

The dashboard check is too strict. It looks for `state UP` in the interface, but WireGuard's `wg-quick@wg0` service runs in "exited" mode (which is normal and correct).

## Solution 1: Check If It's Actually Working (Recommended First Step)

Even if the dashboard says "down", your VPN might be working perfectly! Test it:

```bash
# On your server, run:
sudo wg show

# You should see output like:
# interface: wg0
#   public key: xxx...
#   private key: (hidden)
#   listening port: 51820
#
# peer: xxx...
#   endpoint: xx.xx.xx.xx:xxxxx
#   allowed ips: 10.8.0.2/32
#   latest handshake: 30 seconds ago    <- This means it's WORKING!
```

**If you see "latest handshake" recently (<2 minutes), your VPN IS working!** The dashboard is just showing a false alarm.

---

## Solution 2: Verify WireGuard Is Actually Running

```bash
# Check service status
sudo systemctl status wg-quick@wg0

# Should show "active (exited)" <- This is NORMAL and CORRECT!
```

**Important:** `active (exited)` is the **correct** status for WireGuard! It means:
- ✅ The interface is configured
- ✅ The tunnel is active  
- ✅ Traffic is flowing
- ✅ Everything is working as designed

---

## Solution 3: Fix the Dashboard Detection

The dashboard uses this check:
```bash
ip addr show wg0 | grep "state UP"
```

But WireGuard interfaces may not show "UP" in the traditional sense.

### Quick Manual Check

```bash
# Better check - see if interface exists and has IP
ip addr show wg0

# Should show something like:
# 5: wg0: <POINTOPOINT,NOARP,UP,LOWER_UP> ...
#     inet 10.8.0.1/24 scope global wg0
```

If you see `10.8.0.1/24`, your interface IS up and working!

---

## Solution 4: Restart WireGuard to Force "UP" State

Sometimes restarting helps the interface show correctly:

```bash
# Restart WireGuard
sudo systemctl restart wg-quick@wg0

# Wait 3 seconds
sleep 3

# Check interface again
ip addr show wg0

# Refresh dashboard
# Go to: http://YOUR_SERVER_IP:8080 and click "Refresh Status"
```

---

## Solution 5: Use Command Line Instead of Dashboard

If the dashboard keeps showing "down" but everything works:

```bash
# Check active connections
sudo wg show

# Add new clients
sudo ./wireguard-oracle-setup.sh --add-client phone

# View client config
sudo cat /etc/wireguard/client_phone.conf

# Generate QR code for mobile
sudo qrencode -t ansiutf8 < /etc/wireguard/client_phone.conf

# Check who's connected
sudo wg show wg0 latest-handshakes
```

---

## Understanding "Latest Handshake"

The **latest handshake** time is the BEST indicator of VPN health:

| Handshake Time | Status | Meaning |
|---------------|--------|---------|
| < 2 minutes | ✅ **ACTIVE** | Client is currently connected and sending data |
| 2-5 minutes | ⚠️ **IDLE** | Connected but no recent activity |
| > 5 minutes | ❌ **STALE** | Client disconnected or connection dead |
| (never) | ❌ **NEVER CONNECTED** | Client never successfully connected |

Example:
```bash
$ sudo wg show

peer: abc123...
  endpoint: 1.2.3.4:51820
  allowed ips: 10.8.0.2/32
  latest handshake: 45 seconds ago    <- ✅ ACTIVELY CONNECTED!
  transfer: 10.2 MiB received, 50.1 MiB sent
```

---

## Diagnostic Commands

Run these to verify everything is actually working:

```bash
# 1. Check WireGuard service
sudo systemctl status wg-quick@wg0
# Expected: "active (exited)" <- This is GOOD!

# 2. Check interface exists
ip link show wg0
# Expected: Interface listed with IP

# 3. Check active peers
sudo wg show
# Expected: Shows connected clients with recent handshake

# 4. Check IP forwarding
sysctl net.ipv4.ip_forward
# Expected: net.ipv4.ip_forward = 1

# 5. Check NAT rules
sudo iptables -t nat -L POSTROUTING -n | grep MASQUERADE
# Expected: Shows masquerade rule for 10.8.0.0/24

# 6. Check if clients can ping server
# On Windows client (when connected):
ping 10.8.0.1
# Expected: Replies from 10.8.0.1

# 7. Check if internet works through VPN
# On Windows client (when connected):
ping 8.8.8.8
# Expected: Replies from 8.8.8.8
```

---

## The Bottom Line

**Don't panic if dashboard says "Interface down"!**

Your VPN is working correctly if:
- ✅ `sudo systemctl status wg-quick@wg0` shows "active (exited)"
- ✅ `sudo wg show` displays peer connections
- ✅ `latest handshake` shows recent activity
- ✅ You can `ping 10.8.0.1` from your client device
- ✅ You can access the internet through the VPN

The dashboard's "interface down" message is often a **false alarm** due to how it checks the interface state.

---

## Still Having Real Connection Issues?

If clients **actually cannot connect** or have **no internet**, run:

```bash
# This fixes real connectivity problems
sudo ./complete-fix.sh

# Then test from client device:
ping 10.8.0.1    # Test VPN connection
ping 8.8.8.8     # Test internet access
```

---

## Need Password Protection for Dashboard?

The current dashboard has **NO password protection**! Anyone with your server IP can access it.

**Security recommendations:**

### Option 1: Restrict Access by IP (Best)
In Oracle Cloud Console:
1. Go to: Networking → VCN → Security Lists
2. Find the rule for TCP port 8080
3. Change Source CIDR from `0.0.0.0/0` to `YOUR_HOME_IP/32`
4. Get your IP from: https://whatismyip.com

Now only your IP can access the dashboard!

### Option 2: Stop Dashboard, Use Command Line
```bash
# Stop the dashboard
sudo systemctl stop wireguard-dashboard
sudo systemctl disable wireguard-dashboard

# Use command line to manage clients instead
sudo ./wireguard-oracle-setup.sh --add-client <name>
```

### Option 3: Use SSH Tunnel (Advanced)
```bash
# From your local machine:
ssh -L 8080:localhost:8080 user@your-server-ip

# Then access dashboard at:
# http://localhost:8080
# (Only accessible through SSH tunnel)
```

---

## Quick Summary

| Issue | Solution |
|-------|----------|
| Dashboard says "down" but VPN works | **Ignore it!** Check `sudo wg show` instead |
| Want to check real status | Run `sudo wg show` and look for recent handshakes |
| Need to restart WireGuard | `sudo systemctl restart wg-quick@wg0` |
| Dashboard won't update | Click "Refresh Status" or use CLI commands |
| Need password on dashboard | Restrict by IP in Oracle Cloud Security List |
| Actually no internet | Run `sudo ./complete-fix.sh` |

---

**Remember:** `sudo wg show` is your best friend for checking VPN health. If it shows recent handshakes, your VPN is working perfectly regardless of what the dashboard says!
