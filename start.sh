#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_NIX=0
INSTALL_NIX_DARWIN=0

for arg in "$@"; do
    case $arg in
        --install-nix)
            INSTALL_NIX=1
            shift
            ;;
        --install-nix-darwin)
            INSTALL_NIX_DARWIN=1
            shift
            ;;
        --choice=*)
            CHOICE="${arg#*=}"
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            exit 1
            ;;
    esac
done

log_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

backup_existing_file() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        local timestamp
        timestamp=$(date +%s)
        local backup_path="${file_path}.backup-before-nix.${timestamp}"
        log_warning "$file_path already exists. Backing up to $backup_path."
        sudo mv "$file_path" "$backup_path" || {
            log_error "Failed to back up $file_path to $backup_path."
            exit 1
        }
    fi
}

check_system_requirements() {
    log_info "Checking system requirements..."
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is intended for macOS only."
        exit 1
    fi
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed."
        exit 1
    fi
}

install_nix() {
    if ! command -v nix &> /dev/null; then
        log_info "Installing Nix..."
        
        sudo rm -f /etc/bashrc.backup-before-nix
        sudo rm -f /etc/zshrc.backup-before-nix
        sudo rm -f /etc/bash.bashrc.backup-before-nix
        
        sh <(curl -L https://nixos.org/nix/install) || {
            log_error "Nix installation failed."
            exit 1
        }
        
        if [[ -f '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]]; then
            . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
        else
            log_error "Could not find nix-daemon.sh after installation."
            exit 1
        fi
    fi
}

install_nix_darwin() {
    local MAC_FLAKE_PATH="$HOME/nix-config/Mac#rohan"
    log_info "Installing Nix Darwin..."
    mkdir -p "$HOME/.config/nix"
    local files_to_backup=(
        "/etc/bashrc"
        "/etc/profile.d/nix.sh"
        "/etc/zshrc"
        "/etc/bash.bashrc"
        "/etc/zsh/zshrc"
    )
    for file in "${files_to_backup[@]}"; do
        backup_existing_file "$file"
    done
    
    if ! nix run nix-darwin --extra-experimental-features "nix-command flakes" -- switch \
        --flake "$MAC_FLAKE_PATH" \
        --verbose \
        --impure \
        --max-jobs 20 \
        --cores 7; then
        log_error "Failed to switch Nix Darwin configuration"
        exit 1
    fi
    log_info "Nix Darwin installation completed successfully."
}

rebuild_nix_darwin() {
    local MAC_FLAKE_PATH="$HOME/nix-config/Mac#rohan"
    log_info "Rebuilding Nix Darwin configuration..."
    if ! darwin-rebuild switch --flake "$MAC_FLAKE_PATH"; then
        log_error "Failed to rebuild Nix Darwin configuration"
        exit 1
    fi
    log_info "Nix Darwin configuration rebuild completed successfully."
}

main() {
    check_system_requirements
    if [[ -z "${CHOICE:-}" ]]; then
        echo "Available options:"
        echo "1: Build ISO"
        echo "2: Install Nix Darwin"
        echo "3: Rebuild Nix Darwin"
        read -p "Enter your choice (1/2/3): " CHOICE
    fi
    case $CHOICE in
        1)
            install_nix
            build_iso
            ;;
        2)
            install_nix
            install_nix_darwin
            ;;
        3)
            rebuild_nix_darwin
            ;;
        *)
            log_error "Invalid choice: $CHOICE"
            exit 1
            ;;
    esac
}

main