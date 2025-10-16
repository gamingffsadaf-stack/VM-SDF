#!/usr/bin/env bash
#
# setup_ubuntu.sh - Ubuntu specific setup
#

#######################################
# Setup Ubuntu for RDP
#######################################
setup_ubuntu() {
    log "Starting Ubuntu setup..."
    
    # Update package lists
    update_apt_cache
    
    # Install common packages
    install_common_packages
    
    # Ubuntu-specific packages
    log "Installing Ubuntu-specific packages..."
    
    # Install desktop environment if not present
    if ! dpkg -l | grep -q "ubuntu-desktop\|xubuntu-desktop\|lubuntu-desktop"; then
        log "Installing XFCE desktop environment..."
        ensure_package xfce4
        ensure_package xfce4-goodies
    fi
    
    # Install RDP server
    ensure_package xrdp
    
    # Install additional tools
    ensure_package dbus-x11
    ensure_package xorgxrdp
    
    # Configure xrdp for Ubuntu
    log "Configuring xrdp for Ubuntu..."
    
    if [[ -f /etc/xrdp/xrdp.ini ]]; then
        # Backup original config
        cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.bak 2>/dev/null || true
        
        # Configure for better performance
        sed -i 's/max_bpp=32/max_bpp=24/' /etc/xrdp/xrdp.ini 2>/dev/null || true
    fi
    
    # Configure polkit for color management (fixes common Ubuntu RDP issue)
    log "Configuring polkit for RDP..."
    cat > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla <<'EOF'
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF
    
    # Create .xsessionrc for users
    log "Configuring default X session..."
    cat > /etc/skel/.xsessionrc <<'EOF'
#!/bin/sh
export XDG_SESSION_DESKTOP=xfce
export XDG_DATA_DIRS=/usr/share/xfce4:/usr/local/share:/usr/share:/var/lib/snapd/desktop
export XDG_CONFIG_DIRS=/etc/xdg/xfce4:/etc/xdg
EOF
    chmod +x /etc/skel/.xsessionrc
    
    # Install Windows RDP client tools
    log "Installing RDP client tools..."
    ensure_package freerdp2-x11
    ensure_package remmina
    ensure_package remmina-plugin-rdp
    
    # Install UFW if not present (Ubuntu's default firewall)
    if ! command -v ufw &>/dev/null; then
        ensure_package ufw
    fi
    
    log "Ubuntu setup complete"
}
