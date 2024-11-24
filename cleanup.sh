#!/bin/bash

echo "Cleaning up garbage..."
nix-collect-garbage -d
echo "Cleaning up unused nix store..."
nix-store --gc
echo "Removing stale lock files..."
sudo rm -f /nix/var/nix/profiles/per-user/*/profile.lock
sudo rm -f /nix/var/nix/daemon-socket/socket
sudo rm -f /nix/var/nix/db/db.lock
sudo rm -rf /nix/var/nix/temproots/*
sudo rm -rf /nix/var/nix/gcroots/auto/*
# echo "Removing Homebrew..."
# sudo NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"

# echo "Dont forget to remove the following files:"
# echo "  /opt/homebrew"