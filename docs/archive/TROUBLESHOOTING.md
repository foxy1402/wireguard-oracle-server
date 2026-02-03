# WireGuard on Oracle Linux 8 - Troubleshooting Guide

## Common Issue: No Internet When Connected

This is the most common issue with WireGuard on Oracle Cloud. Here are the specific fixes:

### Issue 1: Oracle Cloud Security List Not Configured

**Symptoms:** Client connects but no internet access

**Fix:**
1. Log into Oracle Cloud Console
2. Go to: Hamburger Menu → Networking → Virtual Cloud Networks
3. Click your VCN → Click "Security Lists" → Click "Default Security List"
4. Click "Add Ingress Rules"
5. Add:
   - Source CIDR: `0.0.0.0/0`
   - IP Protocol: `UDP`
   - Destination Port Range: `51820`
6. Click "Add Ingress Rules"

### Issue 2: iptables NAT Rules Not Working

**Symptoms:** Client connects but can't access internet

**Diagnosis:**
```bash
# Check if NAT rule exists
sudo iptables -t nat -L POSTROUTING -n -v

# Should show a MASQUERADE rule for 10.8.0.0/24
```

**Fix:**
```bash
# Add NAT rule
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o ens3 -j MASQUERADE

# Make permanent
sudo mkdir -p /etc/iptables
sudo iptables-save > /etc/iptables/rules.v4

# Create systemd service to restore on boot
sudo tee /etc/systemd/system/iptables-restore.service > /dev/null <<EOF
[Unit]
Description=Restore iptables rules
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables/rules.v4
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable iptables-restore.service
```

### Issue 3: IP Forwarding Not Enabled

**Symptoms:** Packets don't route through server

**Diagnosis:**
```bash
# Check IP forwarding status
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

### Issue 4: firewalld Blocking Traffic

**Symptoms:** Connection times out or no internet

**Diagnosis:**
```bash
# Check firewalld status
sudo firewall-cmd --list-all
```

**Fix:**
```bash
# Add WireGuard port
sudo firewall-cmd --permanent --add-port=51820/udp

# Enable masquerading
sudo firewall-cmd --permanent --zone=public --add-masquerade

# Reload firewall
sudo firewall-cmd --reload
```

### Issue 5: MTU Issues

**Symptoms:** Some websites load, others don't; slow speeds

**Fix in Client Config:**
```ini
[Interface]
PrivateKey = <your-key>
Address = 10.8.0.2/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1420  # Add this line

[Peer]
# ... rest of config
```

### Issue 6: DNS Not Working

**Symptoms:** Can ping IPs but can't resolve domain names

**Fix in Client Config:**
```ini
[Interface]
PrivateKey = <your-key>
Address = 10.8.0.2/24
DNS = 1.1.1.1, 8.8.8.8  # Add this line or change DNS servers
```

**Alternative DNS servers:**
- Google: `8.8.8.8, 8.8.4.4`
- Cloudflare: `1.1.1.1, 1.0.0.1`
- Quad9: `9.9.9.9, 149.112.112.112`

### Issue 7: SELinux Blocking WireGuard

**Symptoms:** Service fails to start or permission denied errors

**Temporary Fix:**
```bash
sudo setenforce 0
```

**Permanent Fix:**
```bash
sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
```

## Diagnostic Commands

### Check WireGuard Status
```bash
# Service status
sudo systemctl status wg-quick@wg0

# Interface status
sudo wg show

# Interface details
ip addr show wg0
```

### Check Network Connectivity
```bash
# From server - test if clients can reach server
sudo tcpdump -i wg0

# Check routing
ip route

# Check if packets are being forwarded
sudo iptables -L FORWARD -v -n
```

### Check Firewall Rules
```bash
# iptables NAT table
sudo iptables -t nat -L -n -v

# iptables filter table
sudo iptables -L -n -v

# firewalld
sudo firewall-cmd --list-all
```

### Test Connectivity from Windows Client

After connecting WireGuard on Windows:

```powershell
# Check interface
ipconfig

# Ping WireGuard server
ping 10.8.0.1

# Ping external IP (Google DNS)
ping 8.8.8.8

# Test DNS resolution
nslookup google.com

# Traceroute
tracert google.com
```

## Complete Fix Script

If nothing else works, run this complete fix:

```bash
#!/bin/bash
# Complete WireGuard fix for Oracle Linux 8

# Get primary interface
IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf

# Clear and re-add iptables rules
sudo iptables -t nat -F POSTROUTING
sudo iptables -F FORWARD
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $IFACE -j MASQUERADE
sudo iptables -A FORWARD -i wg0 -j ACCEPT
sudo iptables -A FORWARD -o wg0 -j ACCEPT
sudo iptables -I INPUT -p udp --dport 51820 -j ACCEPT

# Configure firewalld
sudo firewall-cmd --permanent --add-port=51820/udp
sudo firewall-cmd --permanent --zone=public --add-masquerade
sudo firewall-cmd --reload

# Restart WireGuard
sudo systemctl restart wg-quick@wg0

# Save iptables
sudo mkdir -p /etc/iptables
sudo iptables-save > /etc/iptables/rules.v4

echo "Fix applied! Test your connection now."
```

## Oracle Cloud Specific Notes

1. **Always configure Security Lists** - This is the #1 reason WireGuard doesn't work on Oracle Cloud
2. **iptables rules may not persist** - Use the systemd service to restore them
3. **firewalld and iptables** - Oracle Linux uses both, configure both
4. **Network interface name** - Usually `ens3` on Oracle Cloud, but verify with `ip link`

## Verification Checklist

- [ ] IP forwarding enabled (`sysctl net.ipv4.ip_forward` = 1)
- [ ] WireGuard service running (`systemctl status wg-quick@wg0`)
- [ ] iptables NAT rule exists (`iptables -t nat -L POSTROUTING`)
- [ ] firewalld allows port 51820 (`firewall-cmd --list-ports`)
- [ ] Oracle Cloud Security List allows UDP 51820
- [ ] Client can ping server (`ping 10.8.0.1`)
- [ ] Client can ping external IP (`ping 8.8.8.8`)
- [ ] DNS works (`nslookup google.com`)
