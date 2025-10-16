#!/usr/bin/env bash
#
# run.sh - Interactive RDP setup for Debian-based distributions
# Supports: Kali Linux, Ubuntu, Debian
# Usage: sudo ./run.sh
#

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

# Source common functions
# shellcheck source=scripts/setup_common.sh
source "${SCRIPTS_DIR}/setup_common.sh"

# Global variables for user choices
USERNAME=""
USER_PASSWORD=""
ENABLE_LINUX_RDP=""
PASSWORD_LOGIN_ONLY=""
WINDOWS_RDP_IP=""
WINDOWS_RDP_USER=""
WINDOWS_RDP_PASS=""

#######################################
# Check if script is run as root
#######################################
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        echo "Please run: sudo $0"
        exit 1
    fi
}

#######################################
# Display main menu
#######################################
show_menu() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     RDP Setup for Debian-based Systems        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Select your distribution:"
    echo "  1) Kali Linux"
    echo "  2) Ubuntu"
    echo "  3) Debian"
    echo "  4) Configure only (no distro-specific changes)"
    echo "  0) Exit"
    echo ""
}

#######################################
# Prompt for user configuration
#######################################
prompt_configuration() {
    echo -e "\n${GREEN}=== User Configuration ===${NC}"
    
    # Username
    read -rp "Enter username to create [default: user]: " USERNAME
    USERNAME="${USERNAME:-user}"
    
    # Password (secure input)
    while true; do
        echo -e "${YELLOW}Enter password for user '${USERNAME}' (input hidden):${NC}"
        read -rs USER_PASSWORD
        echo ""
        echo -e "${YELLOW}Confirm password:${NC}"
        read -rs USER_PASSWORD_CONFIRM
        echo ""
        
        if [[ "${USER_PASSWORD}" == "${USER_PASSWORD_CONFIRM}" ]]; then
            if [[ ${#USER_PASSWORD} -lt 8 ]]; then
                echo -e "${RED}Warning: Password is less than 8 characters. Please use a stronger password.${NC}"
                read -rp "Continue anyway? (y/n): " CONTINUE
                if [[ "${CONTINUE}" =~ ^[Yy]$ ]]; then
                    break
                fi
            else
                break
            fi
        else
            echo -e "${RED}Passwords do not match. Please try again.${NC}"
        fi
    done
    
    # Linux RDP server
    echo ""
    read -rp "Enable Linux RDP server on this machine? (y/n): " ENABLE_LINUX_RDP
    
    if [[ "${ENABLE_LINUX_RDP}" =~ ^[Yy]$ ]]; then
        read -rp "Permit password login only (more secure than allowing key-based)? (y/n): " PASSWORD_LOGIN_ONLY
    fi
    
    # Windows RDP client configuration
    echo ""
    echo -e "${GREEN}=== Windows RDP Client Configuration (Optional) ===${NC}"
    read -rp "Enter Windows RDP target IP (leave empty to skip): " WINDOWS_RDP_IP
    
    if [[ -n "${WINDOWS_RDP_IP}" ]]; then
        read -rp "Enter Windows RDP username: " WINDOWS_RDP_USER
        echo -e "${YELLOW}Enter Windows RDP password (input hidden):${NC}"
        read -rs WINDOWS_RDP_PASS
        echo ""
    fi
}

#######################################
# Create user account
#######################################
create_user_account() {
    log "Creating user account: ${USERNAME}"
    
    # Check if user already exists
    if id "${USERNAME}" &>/dev/null; then
        log "User '${USERNAME}' already exists. Updating password..."
        echo "${USERNAME}:${USER_PASSWORD}" | chpasswd
    else
        # Create user with home directory
        useradd -m -s /bin/bash "${USERNAME}"
        echo "${USERNAME}:${USER_PASSWORD}" | chpasswd
        log "User '${USERNAME}' created successfully"
    fi
    
    # Add user to sudo group
    if ! groups "${USERNAME}" | grep -q sudo; then
        usermod -aG sudo "${USERNAME}"
        log "User '${USERNAME}' added to sudo group"
    fi
}

#######################################
# Setup Linux RDP server
#######################################
setup_linux_rdp() {
    if [[ ! "${ENABLE_LINUX_RDP}" =~ ^[Yy]$ ]]; then
        log "Skipping Linux RDP server setup"
        return
    fi
    
    log "Setting up Linux RDP server (xrdp)"
    
    # Install xrdp and desktop environment
    ensure_package xrdp
    ensure_package xfce4
    ensure_package xfce4-goodies
    
    # Configure xrdp
    if [[ -f /etc/xrdp/startwm.sh ]]; then
        # Backup original
        cp /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh.bak 2>/dev/null || true
        
        # Configure to use xfce
        cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
# xrdp X session start script
if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi

# Start xfce4 session
startxfce4
EOF
        chmod +x /etc/xrdp/startwm.sh
    fi
    
    # Enable and start xrdp service
    systemctl enable xrdp 2>/dev/null || true
    systemctl restart xrdp 2>/dev/null || true
    
    # Open firewall port
    open_firewall_port 3389 "tcp"
    
    log "Linux RDP server configured successfully"
}

#######################################
# Setup Windows RDP client
#######################################
setup_windows_rdp_client() {
    if [[ -z "${WINDOWS_RDP_IP}" ]]; then
        log "Skipping Windows RDP client setup"
        return
    fi
    
    log "Setting up Windows RDP client tools"
    
    # Install freerdp
    ensure_package freerdp2-x11
    
    log "Windows RDP client tools installed"
}

#######################################
# Print connection instructions
#######################################
print_connection_info() {
    local public_ip
    local private_ip
    
    public_ip=$(get_public_ip)
    private_ip=$(get_private_ip)
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          Setup Complete!                       ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ "${ENABLE_LINUX_RDP}" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}=== Connect TO this Linux machine via RDP ===${NC}"
        echo "Public IP:  ${public_ip}"
        echo "Private IP: ${private_ip}"
        echo "Port:       3389"
        echo "Username:   ${USERNAME}"
        echo ""
        echo "From Windows:"
        echo "  1. Open Remote Desktop Connection (mstsc.exe)"
        echo "  2. Enter: ${public_ip}:3389"
        echo "  3. Login with username: ${USERNAME}"
        echo ""
        echo "From Linux:"
        echo "  xfreerdp /u:${USERNAME} /v:${public_ip}:3389"
        echo ""
        echo -e "${YELLOW}Security Warning:${NC}"
        echo "  - Ensure your firewall is properly configured"
        echo "  - Do NOT expose RDP to public internet without VPN"
        echo "  - Use strong passwords and consider SSH tunneling"
        echo ""
    fi
    
    if [[ -n "${WINDOWS_RDP_IP}" ]]; then
        echo -e "${BLUE}=== Connect FROM this Linux machine to Windows ===${NC}"
        echo "Target IP:  ${WINDOWS_RDP_IP}"
        echo "Username:   ${WINDOWS_RDP_USER}"
        echo ""
        echo "Run this command:"
        if [[ -n "${WINDOWS_RDP_PASS}" ]]; then
            echo "  xfreerdp /u:${WINDOWS_RDP_USER} /p:'${WINDOWS_RDP_PASS}' /v:${WINDOWS_RDP_IP}"
        else
            echo "  xfreerdp /u:${WINDOWS_RDP_USER} /v:${WINDOWS_RDP_IP}"
        fi
        echo ""
        echo "Or use Remmina GUI (if installed):"
        echo "  remmina"
        echo ""
    fi
}

#######################################
# Main execution flow
#######################################
main() {
    check_root
    
    # Show menu and get choice
    show_menu
    read -rp "Enter your choice [0-4]: " CHOICE
    
    case "${CHOICE}" in
        1)
            log "Selected: Kali Linux"
            DISTRO="kali"
            ;;
        2)
            log "Selected: Ubuntu"
            DISTRO="ubuntu"
            ;;
        3)
            log "Selected: Debian"
            DISTRO="debian"
            ;;
        4)
            log "Selected: Configure only"
            DISTRO="none"
            ;;
        0)
            log "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
    
    # Prompt for configuration
    prompt_configuration
    
    # Detect actual distribution
    local detected_distro
    detected_distro=$(detect_distro)
    log "Detected distribution: ${detected_distro}"
    
    # Run distro-specific setup if not "configure only"
    if [[ "${DISTRO}" != "none" ]]; then
        case "${DISTRO}" in
            kali)
                # shellcheck source=scripts/setup_kali.sh
                source "${SCRIPTS_DIR}/setup_kali.sh"
                setup_kali
                ;;
            ubuntu)
                # shellcheck source=scripts/setup_ubuntu.sh
                source "${SCRIPTS_DIR}/setup_ubuntu.sh"
                setup_ubuntu
                ;;
            debian)
                # shellcheck source=scripts/setup_debian.sh
                source "${SCRIPTS_DIR}/setup_debian.sh"
                setup_debian
                ;;
        esac
    fi
    
    # Common setup tasks
    create_user_account
    setup_linux_rdp
    setup_windows_rdp_client
    
    # Print final instructions
    print_connection_info
    
    log "All done! Enjoy your RDP setup."
}

# Run main function
main "$@"
