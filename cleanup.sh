#!/bin/bash

echo "Cleaning up garbage..."
nix-collect-garbage
echo "Cleaning up unused nix store..."
nix-store --gc
echo 
sudo rm -f /nix/var/nix/profiles/per-user/*/profile.lock
echo "Removing Homebrew..."
sudo NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"

echo "Dont forget to remove the following files:"
echo "  /opt/homebrew"