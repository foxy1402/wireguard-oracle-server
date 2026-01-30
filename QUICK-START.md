# WireGuard Oracle Cloud - One-Page Quick Start

## 📋 Checklist Version (For Complete Beginners)

### Before You Start
- [ ] You have an Oracle Cloud account
- [ ] You have created an Oracle Linux 8 ARM instance (free tier is fine)
- [ ] You can SSH into your instance
- [ ] You have the instance's public IP address

---

### Part 1: Server Setup (On Oracle Instance)

**⏱️ Time: 5-10 minutes**

- [ ] **Step 1.1:** SSH into your Oracle instance
  ```bash
  ssh opc@YOUR_INSTANCE_IP
  ```

- [ ] **Step 1.2:** Download the setup scripts
  ```bash
  sudo dnf install -y git
  git clone https://github.com/foxy1402/wireguard-oracle-server.git
  cd wireguard-oracle-server
  ```

- [ ] **Step 1.3:** Make scripts executable
  ```bash
  chmod +x wireguard-oracle-setup.sh complete-fix.sh health-check.sh
  ```

- [ ] **Step 1.4:** Run the installation script
  ```bash
  sudo ./wireguard-oracle-setup.sh
  ```
  ✅ Wait 2-3 minutes for installation to complete
  
  ✅ A QR code will be displayed (save a screenshot if using mobile!)
  
  ✅ Write down the file path shown (usually `/etc/wireguard/client_windows11.conf`)

---

### Part 2: Oracle Cloud Firewall (In Web Browser)

**⏱️ Time: 2-3 minutes**

**⚠️ CRITICAL - This is why most people fail! Don't skip!**

- [ ] **Step 2.1:** Open https://cloud.oracle.com and login

- [ ] **Step 2.2:** Click hamburger menu (☰) → **Networking** → **Virtual Cloud Networks**

- [ ] **Step 2.3:** Click on your VCN name (probably starts with "vcn-")

- [ ] **Step 2.4:** On the left sidebar, click **"Security Lists"**

- [ ] **Step 2.5:** Click **"Default Security List for vcn-..."**

- [ ] **Step 2.6:** Click the blue **"Add Ingress Rules"** button

- [ ] **Step 2.7:** Fill in the form:
  - **Source Type:** CIDR
  - **Source CIDR:** `0.0.0.0/0`
  - **IP Protocol:** UDP
  - **Source Port Range:** (leave empty)
  - **Destination Port Range:** `51820`
  - **Description:** WireGuard VPN

- [ ] **Step 2.8:** Click **"Add Ingress Rules"** at the bottom

- [ ] **Step 2.9:** Verify: You should see the new rule in the list with "UDP" and "51820"

✅ **Firewall configured!**

---

### Part 3: Get Client Config (Back to SSH Terminal)

**⏱️ Time: 1 minute**

- [ ] **Step 3.1:** Display the client configuration
  ```bash
  sudo cat /etc/wireguard/client_windows11.conf
  ```

- [ ] **Step 3.2:** Copy ALL the text (from `[Interface]` to the end)

- [ ] **Step 3.3:** On your computer, create a new file called `wireguard.conf`

- [ ] **Step 3.4:** Paste the copied text into the file and save

✅ **Client config downloaded!**

---

### Part 4: Client Setup (On Your Device)

**⏱️ Time: 2-3 minutes**

#### For Windows:

- [ ] **Step 4.1:** Download WireGuard from https://www.wireguard.com/install/

- [ ] **Step 4.2:** Install WireGuard

- [ ] **Step 4.3:** Open the WireGuard application

- [ ] **Step 4.4:** Click **"Add Tunnel"** → **"Import tunnel(s) from file"**

- [ ] **Step 4.5:** Select the `wireguard.conf` file you created

- [ ] **Step 4.6:** Click **"Activate"**

#### For Mac:

- [ ] **Step 4.1:** Install WireGuard from the App Store

- [ ] **Step 4.2:** Click WireGuard menu bar icon → **"Import Tunnel(s) from File"**

- [ ] **Step 4.3:** Select your `wireguard.conf` file

- [ ] **Step 4.4:** Click the toggle to activate

#### For Mobile (Android/iOS):

- [ ] **Step 4.1:** Install WireGuard from Play Store / App Store

- [ ] **Step 4.2:** Tap the **+** button

- [ ] **Step 4.3:** Tap **"Scan from QR code"**

- [ ] **Step 4.4:** Scan the QR code from your screenshot (Step 1.4)

- [ ] **Step 4.5:** Tap the toggle to activate

✅ **WireGuard connected!**

---

### Part 5: Test Connection

**⏱️ Time: 1 minute**

#### On Windows (PowerShell or Command Prompt):

- [ ] **Test 1:** Ping the VPN server
  ```bash
  ping 10.8.0.1
  ```
  ✅ Expected: **Reply from 10.8.0.1**

- [ ] **Test 2:** Ping the internet
  ```bash
  ping 8.8.8.8
  ```
  ✅ Expected: **Reply from 8.8.8.8**

- [ ] **Test 3:** Test DNS
  ```bash
  ping google.com
  ```
  ✅ Expected: **Reply from an IP address**

#### On Mac/Linux (Terminal):
Same commands as Windows above

#### On Mobile:
- [ ] Open a web browser and visit any website
  ✅ Expected: **Website loads normally**

---

## 🎉 Success Criteria

**If ALL these are true, you're done!**
- ✅ WireGuard shows "Active" or "Connected"
- ✅ `ping 10.8.0.1` gets replies
- ✅ `ping 8.8.8.8` gets replies
- ✅ Websites load in your browser
- ✅ Your IP has changed (check at https://whatismyip.com)

**Congratulations! Your VPN is working! 🎉**

---

## ❌ If Something Went Wrong

### Problem: Can ping 10.8.0.1 but NOT 8.8.8.8

**This is the most common issue!**

**Solution:**
```bash
# On your Oracle instance, run:
sudo ./complete-fix.sh

# Wait for it to complete, then:
# 1. Disconnect WireGuard on your device
# 2. Wait 5 seconds
# 3. Reconnect
# 4. Test again with: ping 8.8.8.8
```

### Problem: Cannot connect at all

**Solution:**
1. Double-check Part 2 (Oracle Cloud firewall) - did you add the rule correctly?
2. Make sure you used UDP (not TCP) and port 51820
3. Verify the rule shows "0.0.0.0/0" as the source

### Problem: Connected but websites don't load

**Solution:**
```bash
# On your device, edit the WireGuard tunnel config
# Add this line under [Interface]:
MTU = 1420

# Save and reconnect
```

### Still Having Issues?

**Run health check on server:**
```bash
sudo ./health-check.sh
```

**This will tell you exactly what's wrong.**

---

## 📱 Add More Devices

Want to connect your phone, tablet, or another computer?

```bash
# On your Oracle instance, run:
sudo ./wireguard-oracle-setup.sh --add-client myphone

# This will:
# - Generate a new config
# - Show a QR code (for mobile)
# - Save to /etc/wireguard/client_myphone.conf

# To see the config file:
sudo cat /etc/wireguard/client_myphone.conf

# To see the QR code again:
sudo qrencode -t ansiutf8 < /etc/wireguard/client_myphone.conf
```

Then repeat Part 4 and Part 5 for the new device!

---

## 🌐 OPTIONAL: Install Web Dashboard

**Only install this if you want to manage clients through a web browser instead of command line.**

See the full README.md for complete dashboard installation instructions, including:
- How to install the dashboard
- Oracle Cloud firewall configuration for port 8080
- Password setup on first visit
- How to reset forgotten passwords

Quick install:
```bash
# 1. Install dashboard
sudo ./install-dashboard.sh

# 2. Add Oracle Cloud firewall rule for TCP port 8080 (see README.md for details)

# 3. Visit http://YOUR_SERVER_IP:8080 and set password
```

---

## 🔒 Important Security Notes

- ✅ **Keep your config files safe** - they contain private keys
- ✅ **Don't share configs between devices** - create a new one for each device
- ✅ **Never share your server's private key** - it's in `/etc/wireguard/server_private.key`

---

## 📞 Need More Help?

1. Read the full README.md: https://github.com/foxy1402/wireguard-oracle-server
2. Check TROUBLESHOOTING.md for specific error messages
3. Run diagnostics: `sudo ./wireguard-oracle-setup.sh --diagnose`

---

## 💡 Pro Tips

- **Mobile setup:** Just scan the QR code - no typing needed!
- **Lost the QR code?** Generate it again: `sudo qrencode -t ansiutf8 < /etc/wireguard/client_windows11.conf`
- **Check who's connected:** `sudo wg show`
- **Forgot your server's IP?** `curl ifconfig.me`
- **Server rebooted?** WireGuard starts automatically - no action needed!

---

**That's it! Print this page and follow step by step. Each checkbox should take less than 1 minute. Total time: ~15 minutes.** ✅

**Happy browsing securely! 🔒🌐**
