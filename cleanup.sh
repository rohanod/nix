#!/bin/bash

echo "Cleaning up garbage..."
nix-collect-garbage
echo "Cleaning up unused nix store..."
nix-store --gc
echo "Removing Homebrew..."
sudo rm -rf "/opt/homebrew"