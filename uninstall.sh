#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

check_system() {
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is intended for macOS only."
        exit 1
    fi
}

restore_shell_files() {
    if [[ -f "/etc/zshrc.backup-before-nix" ]]; then
        sudo mv /etc/zshrc.backup-before-nix /etc/zshrc
    fi
    if [[ -f "/etc/bashrc.backup-before-nix" ]]; then
        sudo mv /etc/bashrc.backup-before-nix /etc/bashrc
    fi
    if [[ -f "/etc/bash.bashrc.backup-before-nix" ]]; then
        sudo mv /etc/bash.bashrc.backup-before-nix /etc/bash.bashrc
    fi
}

uninstall_nix() {
    log_info "Stopping Nix daemon..."
    sudo launchctl unload /Library/LaunchDaemons/org.nixos.nix-daemon.plist 2>/dev/null || true
    sudo rm -f /Library/LaunchDaemons/org.nixos.nix-daemon.plist
    sudo launchctl unload /Library/LaunchDaemons/org.nixos.darwin-store.plist 2>/dev/null || true
    sudo rm -f /Library/LaunchDaemons/org.nixos.darwin-store.plist

    log_info "Removing build users..."
    sudo dscl . -delete /Groups/nixbld 2>/dev/null || true
    for u in $(sudo dscl . -list /Users | grep _nixbld); do 
        sudo dscl . -delete /Users/$u 2>/dev/null || true
    done

    log_info "Cleaning up fstab..."
    if [[ -f "/etc/fstab" ]]; then
        sudo sed -i'.bak' '/^LABEL=Nix\\040Store.*$/d' /etc/fstab
        sudo sed -i'.bak' '/^UUID=.*\/nix apfs.*$/d' /etc/fstab
    fi

    log_info "Cleaning up synthetic.conf..."
    if [[ -f "/etc/synthetic.conf" ]]; then
        if [[ "$(cat /etc/synthetic.conf)" = "nix" ]]; then
            sudo rm /etc/synthetic.conf
        else
            sudo sed -i'.bak' '/^nix$/d' /etc/synthetic.conf
        fi
    fi

    log_info "Removing Nix files..."
    sudo rm -rf /etc/nix /var/root/.nix-profile /var/root/.nix-defexpr /var/root/.nix-channels
    rm -rf ~/.nix-profile ~/.nix-defexpr ~/.nix-channels

    log_info "Unmounting and removing Nix store volume..."
    if mount | grep -q "/nix"; then
        sudo diskutil unmount force /nix || true
    fi
    
    if diskutil list | grep -q "Nix Store"; then
        local volume_id
        volume_id=$(diskutil list | grep "Nix Store" | awk '{print $NF}')
        sudo diskutil apfs deleteVolume "$volume_id" || {
            log_warning "Could not delete volume. You may need to reboot and run 'sudo diskutil apfs deleteVolume $volume_id'"
        }
    fi

    restore_shell_files

    log_info "Nix has been uninstalled. You may need to restart your system for all changes to take effect."
    log_warning "Note: An empty /nix directory may remain until next reboot - this is normal."
}

main() {
    check_system
    log_warning "This will completely remove Nix from your system."
    read -p "Are you sure you want to continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    uninstall_nix
}

main