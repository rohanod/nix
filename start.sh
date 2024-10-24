#!/bin/bash

for arg in "$@"
do
    case $arg in
        --choice=*)
        CHOICE="${arg#*=}"
        shift
        ;;
        --install-nix=*)
        INSTALL_NIX="${arg#*=}"
        shift
        ;;
        *)
        echo "Unknown option: $arg"
        exit 1
        ;;
    esac
done

check_and_prompt_install_nix() {
    echo "Checking if Nix is installed..."
    if ! command -v nix &> /dev/null
    then
        echo "Nix is not installed."
        if [[ "$INSTALL_NIX" == "1" ]]; then
            install_choice="y"
        else
            read -p "Do you want to install Nix? (y/n): " install_choice
        fi

        if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
            if [ -e /etc/bash.bashrc.backup-before-nix ] || [ -e /etc/zshrc.backup-before-nix ] || [ -e /etc/bashrc.backup-before-nix ]; then
                echo "Cleanup old Nix installing process..."
                [ -e /etc/bash.bashrc.backup-before-nix ] && sudo mv /etc/bash.bashrc.backup-before-nix /etc/bash.bashrc > /dev/null 2>&1
                [ -e /etc/zshrc.backup-before-nix ] && sudo mv /etc/zshrc.backup-before-nix /etc/zshrc > /dev/null 2>&1
                [ -e /etc/bashrc.backup-before-nix ] && sudo mv /etc/bashrc.backup-before-nix /etc/bashrc > /dev/null 2>&1

                sudo sed -i '' '/# Nix/,/# End Nix/d' /etc/zshrc
                sudo sed -i '' '/# Nix/,/# End Nix/d' /etc/bashrc
                sudo sed -i '' '/# Nix/,/# End Nix/d' /etc/bash.bashrc

                sudo launchctl unload /Library/LaunchDaemons/org.nixos.nix-daemon.plist
                sudo rm /Library/LaunchDaemons/org.nixos.nix-daemon.plist
                sudo launchctl unload /Library/LaunchDaemons/org.nixos.darwin-store.plist
                sudo rm /Library/LaunchDaemons/org.nixos.darwin-store.plist

                sudo dscl . -delete /Groups/nixbld
                for u in $(sudo dscl . -list /Users | grep _nixbld); do sudo dscl . -delete /Users/$u; done

                sudo vifs -c 'g/\/nix/d'

                sudo sed -i '' '/nix/d' /etc/synthetic.conf
                [ ! -s /etc/synthetic.conf ] && sudo rm /etc/synthetic.conf

                sudo rm -rf /etc/nix /var/root/.nix-profile /var/root/.nix-defexpr /var/root/.nix-channels ~/.nix-profile ~/.nix-defexpr ~/.nix-channels

                sudo diskutil apfs deleteVolume /nix

                echo "Cleaned up old Nix installing process..."
            fi

            echo "Installing Nix..."
            curl -L https://nixos.org/nix/install | sh 
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

if [[ -z "$CHOICE" ]]; then
    echo "What would you like to do?"
    echo "1. Build a NixOS ISO"
    echo "2. Install nix-darwin for macOS"
    read -p "Enter your choice (1 or 2): " CHOICE
fi

echo "User selected option: $CHOICE"
case $CHOICE in
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