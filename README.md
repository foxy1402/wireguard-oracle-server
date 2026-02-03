# WireGuard VPN Server Setup for Oracle Cloud

> **🎯 Automated WireGuard installation for Oracle Cloud Free Tier**  
> Supports both Oracle Linux and Ubuntu with one-command setup

[![Oracle Cloud](https://img.shields.io/badge/Oracle%20Cloud-Free%20Tier-F80000?logo=oracle)](https://www.oracle.com/cloud/free/)
[![WireGuard](https://img.shields.io/badge/WireGuard-VPN-88171A?logo=wireguard)](https://www.wireguard.com/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## 🚀 Quick Start (30 seconds)

### Choose Your OS:

**📘 Oracle Linux 8** *(Recommended for stability)*
```bash
git clone https://github.com/yourusername/wireguard-oracle-server.git
cd wireguard-oracle-server
chmod +x wireguard-oracle-setup.sh
sudo ./wireguard-oracle-setup.sh
```

**🟠 Ubuntu 20.04/22.04/24.04** *(Better performance)*
```bash
git clone https://github.com/yourusername/wireguard-oracle-server.git
cd wireguard-oracle-server
chmod +x wireguard-ubuntu-setup.sh
sudo ./wireguard-ubuntu-setup.sh
```

**⚠️ Don't forget:** Configure Oracle Cloud Security List (UDP port 51820)

---

## 📚 Full Documentation

| Operating System | Installation Guide | Troubleshooting |
|-----------------|-------------------|-----------------|
| **Oracle Linux 8** | [📘 Complete Oracle Linux Guide](docs/ORACLE-LINUX.md) | Included in guide |
| **Ubuntu 20.04/22.04/24.04** | [🟠 Complete Ubuntu Guide](docs/UBUNTU.md) | Included in guide |

---

## ✨ Features

### Core Features
- ✅ **One-command installation** - Automated setup for Oracle Linux or Ubuntu
- ✅ **Auto-fix scripts** - Automatically solves the "no internet" problem
- ✅ **Health checks** - Verify everything is working correctly
- ✅ **QR code generation** - Easy mobile device setup
- ✅ **Oracle Cloud optimized** - Handles security lists and firewall rules

### Web Dashboard (Optional)
- 🌐 **Web interface** - Manage clients from your browser (port 8080)
- 👥 **Client management** - Add/delete clients via web UI
- 📱 **QR codes** - Generate QR codes instantly
- 📊 **Real-time monitoring** - See active connections and traffic
- 💾 **Config downloads** - Download client configs with one click
- 🔒 **Password protected** - Secure dashboard access

---

## 🎯 What Problem Does This Solve?

Setting up WireGuard on Oracle Cloud is challenging because:
- ❌ Oracle Cloud has special firewall rules (Security Lists)
- ❌ Standard guides don't work on Oracle Linux
- ❌ "Connected but no internet" is extremely common
- ❌ Manual NAT/iptables configuration is complex

**This repository provides:**
- ✅ Automated Oracle Cloud-specific setup
- ✅ Fixes firewall, NAT, and routing automatically
- ✅ Separate scripts for Oracle Linux and Ubuntu
- ✅ Optional web dashboard for easy management
- ✅ Comprehensive troubleshooting guides

---

## 📋 Requirements

### Server (Oracle Cloud Instance)
- **OS:** Oracle Linux 8 *OR* Ubuntu 20.04/22.04/24.04
- **Shape:** Any (Free tier VM.Standard.A1.Flex works perfectly)
- **RAM:** 1 GB minimum (6 GB recommended for free tier)
- **Storage:** 50 GB boot volume
- **Network:** Public IP address

### Client Device
- **WireGuard app:** [Download for your platform](https://www.wireguard.com/install/)
- **Supported:** Windows, macOS, Linux, iOS, Android

---

## 📦 What's Included

### Oracle Linux Scripts
| Script | Purpose |
|--------|---------|
| `wireguard-oracle-setup.sh` | Main installation script |
| `complete-fix.sh` | Auto-fix common issues |
| `health-check.sh` | Diagnostic tool |
| `install-dashboard.sh` | Web dashboard installer |
| `update-and-restart.sh` | Update and restart WireGuard |

### Ubuntu Scripts
| Script | Purpose |
|--------|---------|
| `wireguard-ubuntu-setup.sh` | Main installation script |
| `ubuntu-complete-fix.sh` | Auto-fix common issues |
| `ubuntu-health-check.sh` | Diagnostic tool |
| `install-dashboard-ubuntu.sh` | Web dashboard installer *(template)* |

### Documentation
| File | Description |
|------|-------------|
| `docs/ORACLE-LINUX.md` | Complete Oracle Linux guide with troubleshooting |
| `docs/UBUNTU.md` | Complete Ubuntu guide with troubleshooting |
| `README.md` | This file - main entry point |

---

## 🔧 Basic Usage

### Adding More Clients

**Oracle Linux:**
```bash
sudo ./wireguard-oracle-setup.sh --add-client myphone
```

**Ubuntu:**
```bash
sudo ./wireguard-ubuntu-setup.sh --add-client myphone
```

### Running Diagnostics

**Oracle Linux:**
```bash
sudo ./health-check.sh
```

**Ubuntu:**
```bash
sudo ./ubuntu-health-check.sh
```

### Auto-Fix Issues

**Oracle Linux:**
```bash
sudo ./complete-fix.sh
```

**Ubuntu:**
```bash
sudo ./ubuntu-complete-fix.sh
```

---

## 🌐 Web Dashboard (Optional)

Manage your VPN clients with a beautiful web interface!

### Install Dashboard

**Oracle Linux:**
```bash
sudo ./install-dashboard.sh
```

**Ubuntu:**
```bash
sudo ./install-dashboard-ubuntu.sh  # Template - needs completion
```

### Access Dashboard
1. Open browser: `http://YOUR_SERVER_IP:8080`
2. Set password on first visit
3. Start managing clients!

**Features:**
- Add/delete clients
- Generate QR codes
- Download configs
- Real-time connection status
- Traffic statistics
- Auto-fix button

---

## 🆘 Troubleshooting

### Most Common Issue: "Connected but No Internet"

**Quick Fix:**
```bash
# Oracle Linux
sudo ./complete-fix.sh

# Ubuntu
sudo ./ubuntu-complete-fix.sh
```

### Still Having Issues?

1. **Run health check:**
   ```bash
   # Oracle Linux
   sudo ./health-check.sh
   
   # Ubuntu
   sudo ./ubuntu-health-check.sh
   ```

2. **Check Oracle Cloud Security List** *(90% of problems!)*
   - Navigate to: Oracle Cloud Console → Networking → VCN → Security Lists
   - Verify rule exists: Source `0.0.0.0/0`, Protocol `UDP`, Port `51820`

3. **Read full troubleshooting guide:**
   - [Oracle Linux Troubleshooting](docs/ORACLE-LINUX.md#troubleshooting)
   - [Ubuntu Troubleshooting](docs/UBUNTU.md#troubleshooting)

---

## 📊 Oracle Linux vs Ubuntu

| Feature | Oracle Linux 8 | Ubuntu 22.04 Minimal |
|---------|----------------|---------------------|
| **Free tier support** | ✅ Yes | ✅ Yes |
| **WireGuard install** | `dnf install` (EPEL) | `apt install` (built-in) |
| **Firewall** | `firewalld` | `ufw` + `iptables` |
| **RAM usage** | ~350 MB | ~200 MB |
| **Boot time** | ~20-30 sec | ~10-15 sec |
| **Package updates** | Slower | Faster |
| **Stability** | Excellent | Excellent |
| **LTS support** | Until 2029 | Until 2027 (22.04) |
| **Recommendation** | ⭐ Best for beginners | ⭐ Best for performance |

**Verdict:** Both work perfectly! Choose based on your preference.

---

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on Oracle Cloud
5. Submit a pull request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## ⚠️ Disclaimer

- This is for educational and personal use
- Use at your own risk
- Free tier Oracle Cloud instances may have usage limits
- Always review scripts before running them with `sudo`

---

## 🙏 Acknowledgments

- [WireGuard](https://www.wireguard.com/) - Fast, modern VPN protocol
- [Oracle Cloud](https://www.oracle.com/cloud/free/) - Free tier hosting
- Community contributors and testers

---

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/wireguard-oracle-server/issues)
- **Discussions:** [GitHub Discussions](https://github.com/yourusername/wireguard-oracle-server/discussions)
- **Documentation:** [Full guides](docs/)

---

**Made with ❤️ for the Oracle Cloud Free Tier community**
