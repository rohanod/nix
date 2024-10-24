#!/bin/bash

check_and_prompt_install_nix() {
    echo "Checking if Nix is installed..."
    if ! command -v nix &> /dev/null
    then
        echo "Nix is not installed."
        read -p "Do you want to install Nix? (y/n): " install_choice
        if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
            if [ -e /etc/bash.bashrc.backup-before-nix ] || [ -e /etc/zshrc.backup-before-nix ]; then
                echo "Cleanup old Nix installing process..."
                [ -e /etc/bash.bashrc.backup-before-nix ] && sudo mv /etc/bash.bashrc.backup-before-nix /etc/bash.bashrc > /dev/null 2>&1
                [ -e /etc/zshrc.backup-before-nix ] && sudo mv /etc/zshrc.backup-before-nix /etc/zshrc > /dev/null 2>&1
                echo "Cleaned up old Nix installing process..."
            fi

            echo "Installing Nix..."
            curl -L https://nixos.org/nix/install | sh -s -- --daemon
            source ~/.zshrc
            if [ $? -ne 0 ]; then
                echo "Failed to install Nix. Exiting..."
                exit 1
            fi
            echo "Nix installation completed successfully."
        else
            echo "Nix installation skipped. Exiting..."
            exit 1
        fi
    else
        echo "Nix is already installed."
    fi
}

build_iso() {
    LINUX_FLAKE_PATH="$HOME/.nix/Linux#iso"
    echo "Building the NixOS ISO using flake at $LINUX_FLAKE_PATH..."
    nix build "$LINUX_FLAKE_PATH" --no-link --show-trace
    if [ $? -ne 0 ]; then
        echo "Error occurred during ISO build process. Exiting..."
        exit 1
    fi
    echo "ISO build command executed. Checking if the ISO file exists..."
    ISO_OUTPUT_DIR="./result/iso"
    ISO_NAME="nixos.iso"
    if [ -f "$ISO_OUTPUT_DIR/$ISO_NAME" ]; then
        echo "ISO build successful!"
        echo "ISO is located at: $ISO_OUTPUT_DIR/$ISO_NAME"
    else
        echo "Error: ISO build failed or ISO not found!"
        exit 1
    fi
}

install_nix_darwin() {
    echo "Installing Nix and nix-darwin on macOS..."
    MAC_FLAKE_PATH="/Users/rohan/.nix/Mac#rohan"
    check_and_prompt_install_nix
    echo "Running nix-darwin installation command..."
    sudo --preserve-env=HOME nix run nix-darwin --extra-experimental-features "nix-command flakes" -- switch --flake "$MAC_FLAKE_PATH" --impure --show-trace
    if [ $? -ne 0 ]; then
        echo "Failed to install nix-darwin. Exiting..."
        exit 1
    else
        echo "nix-darwin installation completed successfully!"
    fi
}

echo "What would you like to do?"
echo "1. Build a NixOS ISO"
echo "2. Install nix-darwin for macOS"
read -p "Enter your choice (1 or 2): " choice

echo "User selected option: $choice"
case $choice in
    1)
        echo "Option 1 selected: Build a NixOS ISO."
        check_and_prompt_install_nix
        build_iso
        ;;
    2)
        echo "Option 2 selected: Install nix-darwin for macOS."
        install_nix_darwin
        ;;
    *)
        echo "Invalid choice. Exiting..."
        exit 1
        ;;
esac
