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

check_system_requirements() {
    log_info "Checking system requirements..."
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is intended for macOS only."
        exit 1
    fi
    local required_tools=("curl" "git" "xcode-select")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            case $tool in
                "xcode-select")
                    log_warning "Command Line Tools not found. Installing..."
                    xcode-select --install || {
                        log_error "Failed to install Command Line Tools."
                        log_info "Please install Command Line Tools manually using 'xcode-select --install'"
                        exit 1
                    }
                    ;;
                *)
                    log_error "$tool is required but not installed."
                    exit 1
                    ;;
            esac
        fi
    done
}

check_filesystem_permissions() {
    log_info "Checking filesystem permissions..."
    local dirs=("/nix" "$HOME/.nix-defexpr" "$HOME/.config/nix")
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_warning "Creating directory: $dir"
            sudo mkdir -p "$dir" || {
                log_error "Failed to create directory: $dir"
                exit 1
            }
        fi
    done
    if [[ -d "/nix" ]]; then
        if [[ "$(stat -f "%u" /nix)" != "$(id -u)" ]]; then
            log_warning "Fixing /nix ownership..."
            sudo chown -R "$(whoami)" /nix || {
                log_error "Failed to fix /nix ownership"
                exit 1
            }
        fi
    fi
}

check_and_prompt_install_nix() {
    if ! command -v nix &> /dev/null; then
        if [[ "$INSTALL_NIX" == "1" ]]; then
            install_choice="y"
        else
            read -p "Nix is not installed. Do you want to install it? (y/n): " install_choice
        fi
        if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
            log_info "Installing Nix..."
            check_filesystem_permissions
            if [[ -f "$HOME/.config/nix/nix.conf" ]]; then
                log_info "Backing up existing nix.conf..."
                cp "$HOME/.config/nix/nix.conf" "$HOME/.config/nix/nix.conf.backup"
            fi
            if ! curl -L https://nixos.org/nix/install | sh; then
                log_error "Nix installation failed. Checking common issues..."
                if ! sudo launchctl list | grep -q "org.nixos.nix-daemon"; then
                    log_warning "nix-daemon service not found. Attempting to load..."
                    if ! sudo launchctl load /Library/LaunchDaemons/org.nixos.nix-daemon.plist; then
                        log_error "Failed to load nix-daemon service"
                        exit 1
                    fi
                fi
                if [[ ! -f "/etc/synthetic.conf" ]] || ! grep -q "^nix" "/etc/synthetic.conf"; then
                    log_warning "Missing /etc/synthetic.conf entry for nix"
                    echo "nix" | sudo tee -a /etc/synthetic.conf
                    log_info "Please restart your computer and run this script again."
                    exit 1
                fi
                exit 1
            fi
            if [[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
                . "$HOME/.nix-profile/etc/profile.d/nix.sh"
            else
                log_error "Nix profile script not found after installation"
                exit 1
            fi
            log_info "Nix installation completed successfully"
        else
            log_info "Nix installation skipped."
            exit 1
        fi
    fi
}

build_iso() {
    LINUX_FLAKE_PATH="$HOME/.nix/Linux#iso"
    log_info "Building ISO..."
    if ! nix build "$LINUX_FLAKE_PATH" --no-link --show-trace; then
        log_error "ISO build failed."
        exit 1
    fi
    ISO_OUTPUT_DIR="./result/iso"
    ISO_NAME="nixos.iso"
    if [ ! -f "$ISO_OUTPUT_DIR/$ISO_NAME" ]; then
        log_error "ISO not found in output directory."
        exit 1
    fi
    log_info "ISO build completed successfully."
}

install_nix_darwin() {
    local MAC_FLAKE_PATH="$HOME/.nix/Mac#rohan"
    log_info "Installing Nix Darwin..."
    mkdir -p "$HOME/.config/nix"
    echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
    log_info "Installing nix-darwin..."
    if ! nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer; then
        log_error "Failed to build nix-darwin installer"
        exit 1
    fi
    if ! ./result/bin/darwin-installer; then
        log_error "Failed to run nix-darwin installer"
        exit 1
    fi
    log_info "Switching to Nix Darwin configuration..."
    if ! nix run nix-darwin --extra-experimental-features "nix-command flakes" -- switch \
        --flake "$MAC_FLAKE_PATH" \
        --verbose \
        --impure \
        --max-jobs 20 \
        --cores 7; then
        log_error "Failed to switch Nix Darwin configuration"
        exit 1
    fi
    log_info "Nix Darwin installation and configuration switch completed successfully"
}

rebuild_nix_darwin() {
    local MAC_FLAKE_PATH="$HOME/.nix/Mac#rohan"
    log_info "Rebuilding Nix Darwin configuration..."
    if ! command -v darwin-rebuild &> /dev/null; then
        log_error "darwin-rebuild command not found"
        if [[ "$INSTALL_NIX_DARWIN" == "1" ]]; then
            install_choice="y"
        else
            read -p "Required tools for rebuilding are missing. Do you want to install Nix Darwin? (y/n): " install_choice
        fi
        if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
            check_and_prompt_install_nix
            install_nix_darwin
        else
            log_error "Rebuild aborted due to missing dependencies."
            exit 1
        fi
    fi
    if ! darwin-rebuild switch --flake "$MAC_FLAKE_PATH"; then
        log_error "Rebuild failed. Attempting to fix common issues..."
        if [[ ! -d "$HOME/.nix/Mac" ]]; then
            log_error "Flake directory not found at $HOME/.nix/Mac"
            exit 1
        fi
        if ! nix flake check "$HOME/.nix/Mac"; then
            log_error "Flake check failed. Please verify your flake.nix configuration."
            exit 1
        fi
        log_info "Attempting rebuild with --show-trace..."
        darwin-rebuild switch --flake "$MAC_FLAKE_PATH" --show-trace
    fi
    log_info "Nix Darwin configuration rebuild completed successfully"
}

adjust_homebrew_group_permissions() {
    local brew_dirs=("/opt/homebrew" "/usr/local/Homebrew")
    for dir in "${brew_dirs[@]}"; do
        if [ -d "$dir" ]; then
            if [ ! -w "$dir" ]; then
                log_warning "Adjusting group permissions for $dir"
                if ! sudo chgrp -R admin "$dir"; then
                    log_error "Failed to change group ownership of $dir"
                    exit 1
                fi
                if ! sudo chmod -R g+w "$dir"; then
                    log_error "Failed to set group write permissions on $dir"
                    exit 1
                fi
                if ! sudo find "$dir" -type d -exec chmod g+s {} \;; then
                    log_error "Failed to set setgid bit on directories in $dir"
                    exit 1
                fi
            fi
        fi
    done
}

main() {
    check_system_requirements
    check_filesystem_permissions
    adjust_homebrew_group_permissions
    if [[ -z "${CHOICE:-}" ]]; then
        echo "Available options:"
        echo "1: Build ISO"
        echo "2: Install Nix Darwin"
        echo "3: Rebuild Nix Darwin"
        read -p "Enter your choice: " CHOICE
    fi
    case $CHOICE in
        1)
            check_and_prompt_install_nix
            build_iso
            ;;
        2)
            if [[ "$INSTALL_NIX_DARWIN" == "1" ]]; then
                install_choice="y"
            else
                read -p "Do you want to install Nix Darwin? (y/n): " install_choice
            fi
            if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
                check_and_prompt_install_nix
                install_nix_darwin
            else
                log_info "Nix Darwin installation skipped."
                exit 1
            fi
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