#!/bin/bash

echo "Cleaning up garbage..."
nix-collect-garbage
echo "Cleaning up unused nix store..."
nix-store --gc
echo "Removing Homebrew..."
sudo NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
sudo rm -rf "/opt/homebrew"