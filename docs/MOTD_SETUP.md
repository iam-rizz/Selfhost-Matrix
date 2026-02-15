# 🎨 Matrix Server MOTD Setup

Custom Message of the Day (MOTD) for Matrix homeserver with elegant design and system information.

---

## 📸 Preview

```
    ███╗   ███╗ █████╗ ████████╗██████╗ ██╗██╗  ██╗
    ████╗ ████║██╔══██╗╚══██╔══╝██╔══██╗██║╚██╗██╔╝
    ██╔████╔██║███████║   ██║   ██████╔╝██║ ╚███╔╝ 
    ██║╚██╔╝██║██╔══██║   ██║   ██╔══██╗██║ ██╔██╗ 
    ██║ ╚═╝ ██║██║  ██║   ██║   ██║  ██║██║██╔╝ ██╗
    ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝

╔════════════════════════════════════════════════════════════════╗
║  Homeserver                                                    ║
╠════════════════════════════════════════════════════════════════╣
║  Hostname:     rizz-matrix                                     ║
║  IP Address:   192.168.1.100                                   ║
║  Kernel:       6.1.0-28-amd64                                  ║
║  Uptime:       15 days, 3 hours                                ║
╠════════════════════════════════════════════════════════════════╣
║  Resources                                                     ║
╠════════════════════════════════════════════════════════════════╣
║  Load Average: 0.45, 0.52, 0.48                                ║
║  Memory:       6.2G / 16G (39%)                                ║
║  Disk Usage:   45G / 200G (23%)                                ║
╠════════════════════════════════════════════════════════════════╣
║  Services                                                      ║
╠════════════════════════════════════════════════════════════════╣
║  Synapse:      ● Running                                       ║
║  Containers:   12/15                                           ║
║  Active Users: 3                                               ║
╚════════════════════════════════════════════════════════════════╝

  Quick Commands:
    docker compose ps              - View all containers
    docker logs -f matrix-synapse  - View Synapse logs
    bash scripts/backup-postgres.sh - Run backup
    htop                           - System monitor

  Documentation: https://github.com/iam-rizz/Selfhost-Matrix
```

---

## 🎨 Features

- **Matrix-themed ASCII art** - Iconic green Matrix logo
- **System Information** - Hostname, IP, kernel, uptime
- **Resource Monitoring** - Load, memory, disk usage
- **Service Status** - Synapse status, container count, active users
- **Quick Commands** - Common admin commands
- **Color-coded** - Easy to read with Matrix green theme
- **Dynamic** - Updates with real system data

---

## 🚀 Installation

### Method 1: SSH Login (Recommended)

Display MOTD on every SSH login:

```bash
# Copy MOTD script
sudo cp scripts/motd.sh /etc/profile.d/matrix-motd.sh
sudo chmod +x /etc/profile.d/matrix-motd.sh

# Disable default MOTD
sudo chmod -x /etc/update-motd.d/*

# Test
bash /etc/profile.d/matrix-motd.sh
```

### Method 2: Manual Display

Run manually when needed:

```bash
bash scripts/motd.sh
```

### Method 3: Alias

Add to `~/.bashrc` or `~/.zshrc`:

```bash
alias motd='bash ~/Selfhost-Matrix/scripts/motd.sh'
```

Then use:
```bash
motd
```

---

## 🎨 Customization

Edit `scripts/motd.sh` to customize:

### Change Colors

```bash
# Matrix theme colors (default)
MATRIX_GREEN='\033[38;5;46m'   # Bright green
CYAN='\033[38;5;51m'           # Cyan borders
PURPLE='\033[38;5;141m'        # Purple hostname

# Alternative color schemes:
# Blue theme
MATRIX_GREEN='\033[38;5;33m'   # Blue
CYAN='\033[38;5;39m'           # Light blue

# Red theme
MATRIX_GREEN='\033[38;5;196m'  # Red
CYAN='\033[38;5;203m'          # Light red
```

### Add Custom Sections

```bash
# Add after Services section
echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${RESET}  ${BOLD}Custom Section${RESET}                                            ${CYAN}║${RESET}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${RESET}  ${GRAY}Custom Info:${RESET}  ${MATRIX_GREEN}Your Data${RESET}"
```

### Change ASCII Art

Replace the Matrix logo with custom ASCII art:

```bash
# Use figlet or other ASCII art generators
figlet -f banner "MATRIX" > ascii-art.txt
```

---

## 📊 Information Displayed

### Homeserver Section
- **Hostname** - Server hostname
- **IP Address** - Primary IP address
- **Kernel** - Linux kernel version
- **Uptime** - How long server has been running

### Resources Section
- **Load Average** - 1, 5, 15 minute load averages
- **Memory** - Used / Total (percentage)
- **Disk Usage** - Used / Total (percentage) for root partition

### Services Section
- **Synapse** - Running status with colored indicator
- **Containers** - Running / Total Docker containers
- **Active Users** - Currently logged in SSH users

---

## 🔧 Troubleshooting

### MOTD not showing on login

**Check if profile.d is sourced:**
```bash
grep -r "profile.d" /etc/profile /etc/bash.bashrc
```

**Manually source:**
```bash
echo "source /etc/profile.d/matrix-motd.sh" >> ~/.bashrc
```

### Colors not displaying

**Check terminal support:**
```bash
echo $TERM
# Should be: xterm-256color or similar
```

**Enable 256 colors:**
```bash
export TERM=xterm-256color
```

### Docker info not showing

**Check Docker permissions:**
```bash
sudo usermod -aG docker $USER
# Logout and login again
```

---

## 🎯 Best Practices

1. **Keep it concise** - Don't overload with information
2. **Update regularly** - Ensure data is current
3. **Test colors** - Verify on different terminals
4. **Performance** - Keep script fast (<1 second)
5. **Error handling** - Gracefully handle missing data

---

## 📚 Related

- [Figlet ASCII Art Generator](http://www.figlet.org/)
- [ANSI Color Codes](https://en.wikipedia.org/wiki/ANSI_escape_code)
- [Linux MOTD Documentation](https://wiki.debian.org/motd)

---

## ✅ Checklist

- [ ] Script installed in `/etc/profile.d/`
- [ ] Executable permissions set
- [ ] Default MOTD disabled
- [ ] Colors display correctly
- [ ] Docker info showing
- [ ] Tested on SSH login
- [ ] Customized to preference
