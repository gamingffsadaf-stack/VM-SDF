# RDP Setup for Debian-based Systems

A comprehensive, interactive installer for setting up RDP (Remote Desktop Protocol) access on Debian-based Linux distributions. Supports Kali Linux, Ubuntu, and Debian with both server and client configurations.

## Features

- 🖥️ **Interactive Menu System** - Easy-to-use interface for configuration
- 🔒 **Security-Focused** - Secure password prompts, firewall configuration, and best practices
- 🔄 **Idempotent** - Safe to run multiple times without breaking your system
- 🐧 **Multi-Distro Support** - Works on Kali Linux, Ubuntu, and Debian
- 🪟 **Bidirectional RDP** - Set up Linux as RDP server AND/OR connect to Windows machines
- 🎨 **Lightweight Desktop** - Uses XFCE4 for optimal performance over RDP

## Quick Start

### Installation

\`\`\`bash
# Clone the repository
git clone https://github.com/yourusername/rdp-setup.git
cd rdp-setup

# Make the script executable
chmod +x run.sh

# Run the installer (requires sudo)
sudo ./run.sh
\`\`\`

### What Gets Installed

Depending on your choices, the installer will set up:

**For Linux RDP Server:**
- xrdp (RDP server)
- XFCE4 desktop environment
- Required X11 and display manager components
- Firewall rules (port 3389)

**For Windows RDP Client:**
- FreeRDP (xfreerdp command-line tool)
- Remmina (optional GUI RDP client)

**Common Tools:**
- curl, wget, net-tools, iproute2
- sudo and user management utilities

## Usage

### Menu Options

When you run `sudo ./run.sh`, you'll see:

\`\`\`
╔════════════════════════════════════════════════╗
║     RDP Setup for Debian-based Systems        ║
╚════════════════════════════════════════════════╝

Select your distribution:
  1) Kali Linux
  2) Ubuntu
  3) Debian
  4) Configure only (no distro-specific changes)
  0) Exit
\`\`\`

**Option 1-3:** Installs distro-specific packages and configurations
**Option 4:** Only configures users and RDP without installing distro packages (useful for re-runs)
**Option 0:** Exit without changes

### Configuration Prompts

After selecting your distribution, you'll be prompted for:

1. **Username** - User account to create (default: "user")
2. **Password** - Secure password for the user (minimum 8 characters recommended)
3. **Enable Linux RDP Server** - Set up this machine as an RDP server (y/n)
4. **Password Login Only** - Security option for RDP authentication (y/n)
5. **Windows RDP Target** - Optional: IP address of Windows machine to connect to
6. **Windows Credentials** - Optional: Username and password for Windows RDP

## Connecting via RDP

### From Windows to Linux

1. **Open Remote Desktop Connection** (mstsc.exe)
2. **Enter the connection details:**
   \`\`\`
   Computer: YOUR_LINUX_IP:3389
   Username: your_username
   \`\`\`
3. **Click Connect** and enter your password

### From Linux to Windows

**Command Line (xfreerdp):**
\`\`\`bash
xfreerdp /u:USERNAME /p:'PASSWORD' /v:WINDOWS_IP
\`\`\`

**GUI (Remmina):**
1. Launch Remmina
2. Click "New Connection"
3. Select "RDP" protocol
4. Enter Windows IP and credentials
5. Click Connect

### From Linux to Linux

\`\`\`bash
xfreerdp /u:USERNAME /v:LINUX_IP:3389
\`\`\`

## Security Considerations

⚠️ **IMPORTANT SECURITY WARNINGS:**

1. **Firewall Configuration**
   - The installer opens port 3389 for RDP
   - Do NOT expose this port directly to the internet
   - Use a VPN or SSH tunnel for remote access

2. **Strong Passwords**
   - Always use passwords with 8+ characters
   - Include uppercase, lowercase, numbers, and symbols
   - Consider using a password manager

3. **Network Security**
   - RDP should only be used on trusted networks
   - For internet access, use SSH tunneling:
     \`\`\`bash
     ssh -L 3389:localhost:3389 user@remote-server
     # Then connect to localhost:3389
     \`\`\`

4. **Regular Updates**
   - Keep your system updated: `sudo apt update && sudo apt upgrade`
   - Monitor security advisories for xrdp

5. **User Permissions**
   - The created user is added to the sudo group
   - Review and restrict permissions as needed

## Troubleshooting

### RDP Connection Refused

**Check if xrdp is running:**
\`\`\`bash
sudo systemctl status xrdp
\`\`\`

**Restart xrdp:**
\`\`\`bash
sudo systemctl restart xrdp
\`\`\`

**Check firewall:**
\`\`\`bash
sudo ufw status
sudo ufw allow 3389/tcp
\`\`\`

### Black Screen After Login

This is often caused by display manager conflicts.

**Solution 1 - Check .xsession file:**
\`\`\`bash
cat ~/.xsession
# Should contain: exec startxfce4
\`\`\`

**Solution 2 - Recreate session file:**
\`\`\`bash
echo "exec startxfce4" > ~/.xsession
chmod +x ~/.xsession
\`\`\`

**Solution 3 - Check xrdp logs:**
\`\`\`bash
sudo tail -f /var/log/xrdp.log
sudo tail -f /var/log/xrdp-sesman.log
\`\`\`

### Connection Slow or Laggy

**Reduce color depth:**
Edit `/etc/xrdp/xrdp.ini`:
\`\`\`ini
max_bpp=16  # Change from 24 or 32
\`\`\`

**Disable desktop effects:**
In XFCE: Settings → Window Manager Tweaks → Compositor → Disable

### Port Already in Use

**Check what's using port 3389:**
\`\`\`bash
sudo netstat -tulpn | grep 3389
\`\`\`

**Kill conflicting process:**
\`\`\`bash
sudo systemctl stop vncserver  # If VNC is running
sudo systemctl disable vncserver
\`\`\`

### Ubuntu Color Management Error

If you see authentication errors on Ubuntu, the installer should have fixed this, but you can manually verify:

\`\`\`bash
cat /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
\`\`\`

### Kali Linux Specific Issues

**Desktop not starting:**
\`\`\`bash
sudo apt install --reinstall kali-desktop-xfce
sudo systemctl restart xrdp
\`\`\`

## Advanced Configuration

### Custom RDP Port

Edit `/etc/xrdp/xrdp.ini`:
\`\`\`ini
port=3390  # Change from 3389
\`\`\`

Then update firewall:
\`\`\`bash
sudo ufw allow 3390/tcp
sudo systemctl restart xrdp
\`\`\`

### Multiple Concurrent Sessions

xrdp supports multiple users connecting simultaneously. Each user gets their own session.

### SSH Tunnel for Secure RDP

**On your local machine:**
\`\`\`bash
ssh -L 3389:localhost:3389 user@remote-linux-server
\`\`\`

**Then connect to:**
\`\`\`
localhost:3389
\`\`\`

## File Structure

\`\`\`
rdp-setup/
├── run.sh                      # Main interactive script
├── scripts/
│   ├── setup_common.sh         # Shared functions and utilities
│   ├── setup_kali.sh          # Kali Linux specific setup
│   ├── setup_ubuntu.sh        # Ubuntu specific setup
│   └── setup_debian.sh        # Debian specific setup
├── README.md                   # This file
└── LICENSE                     # MIT License
\`\`\`

## Compatibility

**Tested on:**
- Kali Linux Rolling (2024-2025)
- Ubuntu 20.04 LTS, 22.04 LTS, 24.04 LTS
- Debian 10 (Buster), 11 (Bullseye), 12 (Bookworm)

**Architectures:**
- x86_64 (amd64)
- ARM64 (aarch64)
- ARMv7 (armhf)

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test on multiple distributions
4. Submit a pull request

## Disclaimer

⚠️ **FOR AUTHORIZED USE ONLY**

This tool is provided for legitimate system administration and personal use. Users are responsible for:

- Ensuring they have authorization to modify systems
- Complying with organizational security policies
- Following applicable laws and regulations
- Securing their RDP connections appropriately

The authors are not responsible for misuse or security breaches resulting from improper configuration.

## License

MIT License - See [LICENSE](LICENSE) file for details

## Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Check existing issues for solutions
- Review the troubleshooting section above

## Changelog

### Version 1.0.0 (2025)
- Initial release
- Support for Kali, Ubuntu, and Debian
- Interactive menu system
- Bidirectional RDP configuration
- Security-focused defaults
- Comprehensive documentation

---

**Made with ❤️ for the Linux community**
\`\`\`

```text file="LICENSE"
MIT License

Copyright (c) 2025 RDP Setup Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
