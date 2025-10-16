#!/usr/bin/env bash
#
# setup_common.sh - Common functions for RDP setup scripts
#

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

#######################################
# Log message with timestamp
# Arguments:
#   Message to log
#######################################
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

#######################################
# Log error message
# Arguments:
#   Error message
#######################################
error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

#######################################
# Log warning message
# Arguments:
#   Warning message
#######################################
warn() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

#######################################
# Ensure package is installed
# Arguments:
#   Package name
#######################################
ensure_package() {
    local package="$1"
    
    if dpkg -l | grep -q "^ii  ${package}"; then
        log "Package '${package}' is already installed"
        return 0
    fi
    
    log "Installing package: ${package}"
    
    # Update apt cache if not updated recently (within last hour)
    local apt_cache="/var/cache/apt/pkgcache.bin"
    if [[ ! -f "${apt_cache}" ]] || [[ $(find "${apt_cache}" -mmin +60 2>/dev/null) ]]; then
        log "Updating apt cache..."
        DEBIAN_FRONTEND=noninteractive apt-get update -qq
    fi
    
    # Install package
    if DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${package}" 2>/dev/null; then
        log "Package '${package}' installed successfully"
        return 0
    else
        warn "Failed to install package '${package}', trying alternative methods..."
        
        # Try with --fix-missing
        if DEBIAN_FRONTEND=noninteractive apt-get install -y --fix-missing "${package}" 2>/dev/null; then
            log "Package '${package}' installed successfully (with --fix-missing)"
            return 0
        fi
        
        error "Failed to install package '${package}'"
        return 1
    fi
}

#######################################
# Detect system architecture
# Returns:
#   Architecture string (amd64, arm64, etc.)
#######################################
detect_arch() {
    local arch
    arch=$(uname -m)
    
    case "${arch}" in
        x86_64)
            echo "amd64"
            ;;
        aarch64)
            echo "arm64"
            ;;
        armv7l)
            echo "armhf"
            ;;
        *)
            echo "${arch}"
            ;;
    esac
}

#######################################
# Detect Linux distribution
# Returns:
#   Distribution name (kali, ubuntu, debian, unknown)
#######################################
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        
        case "${ID}" in
            kali)
                echo "kali"
                ;;
            ubuntu)
                echo "ubuntu"
                ;;
            debian)
                echo "debian"
                ;;
            *)
                echo "unknown"
                ;;
        esac
    elif command -v lsb_release &>/dev/null; then
        local distro
        distro=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        echo "${distro}"
    else
        echo "unknown"
    fi
}

#######################################
# Check if system uses apt package manager
# Returns:
#   0 if apt is available, 1 otherwise
#######################################
check_apt_support() {
    if ! command -v apt-get &>/dev/null; then
        error "This system does not use apt package manager"
        error "Only Debian-based distributions are supported"
        return 1
    fi
    return 0
}

#######################################
# Open firewall port
# Arguments:
#   Port number
#   Protocol (tcp/udp)
#######################################
open_firewall_port() {
    local port="$1"
    local protocol="${2:-tcp}"
    
    log "Opening firewall port ${port}/${protocol}"
    
    # Check if UFW is installed and active
    if command -v ufw &>/dev/null; then
        if ufw status | grep -q "Status: active"; then
            log "Configuring UFW firewall..."
            ufw allow "${port}/${protocol}" 2>/dev/null || warn "Failed to configure UFW"
        else
            log "UFW is installed but not active"
        fi
    fi
    
    # Check if iptables is available
    if command -v iptables &>/dev/null; then
        log "Configuring iptables..."
        
        # Check if rule already exists
        if ! iptables -C INPUT -p "${protocol}" --dport "${port}" -j ACCEPT 2>/dev/null; then
            iptables -A INPUT -p "${protocol}" --dport "${port}" -j ACCEPT || warn "Failed to configure iptables"
            
            # Try to save iptables rules
            if command -v iptables-save &>/dev/null; then
                iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
            fi
        else
            log "iptables rule already exists for port ${port}/${protocol}"
        fi
    fi
    
    log "Firewall configuration complete"
}

#######################################
# Get public IP address
# Returns:
#   Public IP address or "unavailable"
#######################################
get_public_ip() {
    local public_ip
    
    # Try multiple services
    public_ip=$(curl -s -4 ifconfig.me 2>/dev/null || \
                curl -s -4 icanhazip.com 2>/dev/null || \
                curl -s -4 ipinfo.io/ip 2>/dev/null || \
                echo "unavailable")
    
    echo "${public_ip}"
}

#######################################
# Get private IP address
# Returns:
#   Private IP address or "unavailable"
#######################################
get_private_ip() {
    local private_ip
    
    # Try ip command first
    if command -v ip &>/dev/null; then
        private_ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    fi
    
    # Fallback to hostname command
    if [[ -z "${private_ip}" ]] && command -v hostname &>/dev/null; then
        private_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    
    # Fallback to ifconfig
    if [[ -z "${private_ip}" ]] && command -v ifconfig &>/dev/null; then
        private_ip=$(ifconfig 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1)
    fi
    
    echo "${private_ip:-unavailable}"
}

#######################################
# Print IP addresses
#######################################
print_ip() {
    local public_ip
    local private_ip
    
    public_ip=$(get_public_ip)
    private_ip=$(get_private_ip)
    
    echo -e "${BLUE}Public IP:${NC}  ${public_ip}"
    echo -e "${BLUE}Private IP:${NC} ${private_ip}"
}

#######################################
# Update apt cache safely
#######################################
update_apt_cache() {
    log "Updating package lists..."
    
    # Check if apt is locked
    local max_attempts=10
    local attempt=0
    
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [[ ${attempt} -ge ${max_attempts} ]]; then
            error "apt is locked by another process. Please wait and try again."
            return 1
        fi
        warn "Waiting for other apt processes to finish... (${attempt}/${max_attempts})"
        sleep 3
    done
    
    DEBIAN_FRONTEND=noninteractive apt-get update -qq || {
        error "Failed to update package lists"
        return 1
    }
    
    log "Package lists updated successfully"
    return 0
}

#######################################
# Install common packages
#######################################
install_common_packages() {
    log "Installing common packages..."
    
    local packages=(
        "curl"
        "sudo"
        "net-tools"
        "iproute2"
        "wget"
        "ca-certificates"
    )
    
    for package in "${packages[@]}"; do
        ensure_package "${package}"
    done
    
    log "Common packages installed"
}

# Verify apt support on script load
check_apt_support || exit 1
