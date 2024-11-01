#!/bin/bash

# Process command-line arguments
for arg in "$@"
do
    case $arg in
        --install-nix=*)
        INSTALL_NIX="${arg#*=}"
        shift
        ;;
        --choice=*)
        CHOICE="${arg#*=}"
        shift
        ;;
        *)
        echo "Unknown option: $arg"
        exit 1
        ;;
    esac
done

# Function to check and prompt for Nix installation if missing
check_and_prompt_install_nix() {
    if ! command -v nix &> /dev/null
    then
        if [[ "$INSTALL_NIX" == "1" ]]; then
            install_choice="y"
        else
            read -p "Nix is not installed. Do you want to install it? (y/n): " install_choice
        fi

        if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
            echo "Installing Nix..."
            curl -L https://nixos.org/nix/install | sh 
            zsh source ~/.zshrc
            if [ $? -ne 0 ]; then
                echo "Nix installation failed."
                exit 1
            fi
            echo "Nix installation completed."
        else
            echo "Nix installation skipped."
            exit 1
        fi
    fi
}

# Function to build ISO
build_iso() {
    LINUX_FLAKE_PATH="$HOME/.nix/Linux#iso"
    echo "Building ISO..."
    nix build "$LINUX_FLAKE_PATH" --no-link --show-trace
    if [ $? -ne 0 ]; then
        echo "ISO build failed."
        exit 1
    fi
    ISO_OUTPUT_DIR="./result/iso"
    ISO_NAME="nixos.iso"
    if [ ! -f "$ISO_OUTPUT_DIR/$ISO_NAME" ]; then
        echo "ISO not found in output directory."
        exit 1
    fi
    echo "ISO build completed successfully."
}

# Function to install Nix Darwin configuration
install_nix_darwin() {
    MAC_FLAKE_PATH="$HOME/.nix/Mac#rohan"
    echo "Switching Nix Darwin configuration..."
    nix run nix-darwin --extra-experimental-features "nix-command flakes" -- switch --flake "$MAC_FLAKE_PATH" --verbose --impure --max-jobs 20 --cores 7
    if [ $? -ne 0 ]; then
        echo "Nix Darwin configuration switch failed."
        exit 1
    fi
    echo "Nix Darwin configuration switch completed successfully."
}

# Function to rebuild Nix Darwin configuration
rebuild_nix_darwin() {
    MAC_FLAKE_PATH="$HOME/.nix/Mac#rohan"
    echo "Rebuilding Nix Darwin configuration..."

    if ! command -v darwin-rebuild &> /dev/null || ! command -v nix-darwin &> /dev/null; then
        read -p "Required tools for rebuilding are missing. Do you want to install Nix and Nix Darwin? (y/n): " install_darwin
        if [[ "$install_darwin" == "y" || "$install_darwin" == "Y" ]]; then
            check_and_prompt_install_nix
            install_nix_darwin
        else
            echo "Rebuild aborted due to missing dependencies."
            exit 1
        fi
    fi

    darwin-rebuild switch --flake "$MAC_FLAKE_PATH"
    if [ $? -ne 0 ]; then
        echo "Nix Darwin configuration rebuild failed."
        exit 1
    fi
    echo "Nix Darwin configuration rebuild completed successfully."
}

# Prompt for choice if not provided
if [[ -z "$CHOICE" ]]; then
    read -p "Enter your choice (1: Build ISO, 2: Install Nix Darwin, 3: Rebuild Nix Darwin): " CHOICE
fi

# Main logic for choices
case $CHOICE in
    1)
        check_and_prompt_install_nix
        build_iso
        ;;
    2)
        check_and_prompt_install_nix
        install_nix_darwin
        ;;
    3)
        rebuild_nix_darwin
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac
