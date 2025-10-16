#!/usr/bin/env bash
#
# setup_kali.sh - Kali Linux specific setup
#

#######################################
# Setup Kali Linux for RDP
#######################################
setup_kali() {
    log "Starting Kali Linux setup..."
    
    # Update package lists
    update_apt_cache
    
    # Install common packages
    install_common_packages
    
    # Kali-specific packages
    log "Installing Kali-specific packages..."
    
    # Install desktop environment if not present
    if ! dpkg -l | grep -q "kali-desktop-xfce"; then
        log "Installing Kali XFCE desktop environment..."
        ensure_package kali-desktop-xfce
    fi
    
    # Install RDP server
    ensure_package xrdp
    
    # Install additional tools
    ensure_package dbus-x11
    ensure_package xorg
    
    # Disable conflicting services
    log "Configuring Kali-specific services..."
    
    # Stop and disable vncserver if running
    if systemctl is-active --quiet vncserver; then
        systemctl stop vncserver 2>/dev/null || true
        systemctl disable vncserver 2>/dev/null || true
    fi
    
    # Configure xrdp for Kali
    if [[ -f /etc/xrdp/xrdp.ini ]]; then
        # Backup original config
        cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.bak 2>/dev/null || true
        
        # Set security settings
        sed -i 's/security_layer=negotiate/security_layer=rdp/' /etc/xrdp/xrdp.ini 2>/dev/null || true
        sed -i 's/crypt_level=high/crypt_level=high/' /etc/xrdp/xrdp.ini 2>/dev/null || true
    fi
    
    # Create .xsession file for users
    log "Configuring default X session..."
    cat > /etc/skel/.xsession <<'EOF'
#!/bin/sh
# Start XFCE session
exec startxfce4
EOF
    chmod +x /etc/skel/.xsession
    
    # Install Windows RDP client tools
    log "Installing RDP client tools..."
    ensure_package freerdp2-x11
    ensure_package remmina
    ensure_package remmina-plugin-rdp
    
    log "Kali Linux setup complete"
}
