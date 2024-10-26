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
    if ! command -v nix &> /dev/null
    then
        if [[ "$INSTALL_NIX" == "1" ]]; then
            install_choice="y"
        else
            read -p "Do you want to install Nix? (y/n): " install_choice
        fi

        if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
            if [ -e /etc/bash.bashrc.backup-before-nix ] || [ -e /etc/zshrc.backup-before-nix ] || [ -e /etc/bashrc.backup-before-nix ]; then
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
                sudo rm -rf /nix ~/.nix-profile ~/.nix-defexpr ~/.nix-channels ~/.cache/nix

                sudo nix-collect-garbage -d
            fi

            curl -L https://nixos.org/nix/install | sh 
            zsh source ~/.zshrc
            if [ $? -ne 0 ]; then
                exit 1
            fi
        else
            exit 1
        fi
    fi
}

build_iso() {
    LINUX_FLAKE_PATH="$HOME/.nix/Linux#iso"
    nix build "$LINUX_FLAKE_PATH" --no-link --show-trace
    if [ $? -ne 0 ]; then
        exit 1
    fi
    ISO_OUTPUT_DIR="./result/iso"
    ISO_NAME="nixos.iso"
    if [ ! -f "$ISO_OUTPUT_DIR/$ISO_NAME" ]; then
        exit 1
    fi
}

install_nix_darwin() {
    MAC_FLAKE_PATH="/Users/rohan/.nix/Mac#rohan"
    check_and_prompt_install_nix
    sudo chown -R $(whoami) $HOME
    sudo --preserve-env=HOME nix run nix-darwin --extra-experimental-features "nix-command flakes" -- switch --flake "$MAC_FLAKE_PATH" --impure --show-trace
    if [ $? -ne 0 ]; then
        exit 1
    fi
}

if [[ -z "$CHOICE" ]]; then
    read -p "Enter your choice (1 or 2): " CHOICE
fi

case $CHOICE in
    1)
        check_and_prompt_install_nix
        build_iso
        ;;
    2)
        install_nix_darwin
        ;;
    *)
        exit 1
        ;;
esac
