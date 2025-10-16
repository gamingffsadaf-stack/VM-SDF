#!/usr/bin/env bash
#
# setup_debian.sh - Debian specific setup
#

#######################################
# Setup Debian for RDP
#######################################
setup_debian() {
    log "Starting Debian setup..."
    
    # Update package lists
    update_apt_cache
    
    # Install common packages
    install_common_packages
    
    # Debian-specific packages
    log "Installing Debian-specific packages..."
    
    # Install desktop environment if not present
    if ! dpkg -l | grep -q "task-xfce-desktop"; then
        log "Installing XFCE desktop environment..."
        ensure_package xfce4
        ensure_package xfce4-goodies
        ensure_package task-xfce-desktop
    fi
    
    # Install RDP server
    ensure_package xrdp
    
    # Install additional tools
    ensure_package dbus-x11
    
    # Try to install xorgxrdp if available
    if apt-cache show xorgxrdp &>/dev/null; then
        ensure_package xorgxrdp
    else
        warn "xorgxrdp not available in repositories, skipping..."
    fi
    
    # Configure xrdp for Debian
    log "Configuring xrdp for Debian..."
    
    if [[ -f /etc/xrdp/xrdp.ini ]]; then
        # Backup original config
        cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.bak 2>/dev/null || true
        
        # Basic security settings
        sed -i 's/security_layer=negotiate/security_layer=rdp/' /etc/xrdp/xrdp.ini 2>/dev/null || true
    fi
    
    # Configure session startup
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
    
    # Try to install remmina if available
    if apt-cache show remmina &>/dev/null; then
        ensure_package remmina
        ensure_package remmina-plugin-rdp
    else
        warn "remmina not available in repositories, skipping..."
    fi
    
    log "Debian setup complete"
}
