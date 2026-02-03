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