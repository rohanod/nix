#!/bin/bash

if ! command -v nix &> /dev/null
then
    echo "Nix is not installed. Installing Nix..."
    sh <(curl -L https://nixos.org/nix/install)
    if [ $? -ne 0 ]; then
        echo "Failed to install Nix. Exiting..."
        exit 1
    fi
fi

nix run nix-darwin --extra-experimental-features "nix-command flakes" -- switch --flake ~/.nix/#rohan
