# NixOS Flake for creating an ISO with GNOME and automatic installer

{
  description = "NixOS flake for creating an installable ISO with GNOME and automated installation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    pkgs = import nixpkgs { system = "x86_64-linux"; };
  in
  {
    iso = pkgs.nixos { 
      system = "x86_64-linux";
      modules = [
        ({ config, lib, pkgs, ... }: {
          # System Information
          boot.loader.grub.device = "/dev/sda";
          services.openssh.enable = true;

          # User Configuration
          users.users.rohan = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCwibr7onpgL1ju/xeEejAWh04FqMS/RZaVbIjjeKkwTjq+SMSnjPvewRLlMfuAJd30xM3sZAlR5m99scYv+zcJnHNsdem9aq6jjjxX46Z23C2s4A+EYvNMBJU6h790xnkMBVrAvHNhRQw9wZxNk7M98f1sg5buQDZc9HElCr4DAo4kytlCyxP1xh0fpkDHcNV+X8l5IhR48kIInuteemgLcNdfL+vRV1B2nNgjsxKf5/prMXicxcybJrGY66mQLec4/m7pmIkjkGYXAXmPjwZKIUXCsU8A94hb4crPv5T2c7Nb7TKFwrLWHKbu/1Zj/o14rvlFO+8exWdrDqfOq9JZouPTrkv7Vub4CsqNaLobBVYeyUFwUL7A4eTPkNSsN8/mczbonG8aMG5GsAG9bjZBp6VWDWykSF1TfpaOrFi2AU6xvD0KZdSWjLQxtKQ/Byu/HcWy/XpQDMBZTxqJS82XxQXeLr+aCA7AtFVh+6K/bRTPAq8aFJfaBP9SWhfCLzc= rohan@good.local" ];
            initialPassword = "rohan";
            shell = pkgs.zsh;
          };

          # Enable oh-my-posh
          programs.oh-my-posh.enable = true;

          # Enable GNOME
          services.xserver.enable = true;
          services.xserver.displayManager.gdm.enable = true;
          services.xserver.desktopManager.gnome.enable = true;

          # Set Firefox as default browser and VS Code as the default text editor
          programs.firefox.enable = true;
          programs.vscode.enable = true;

          # Additional Packages
          environment.systemPackages = with pkgs; [
            pkgs.tmux
            pkgs.curl
            pkgs.git
            pkgs.pipx
            pkgs.python3
            pkgs.python3Packages.pip
            pkgs.docker
            pkgs.docker-compose
            pkgs.go
            pkgs.vscode
            pkgs.vscode-extensions.github.copilot
            pkgs.vscode-extensions.github.copilot-chat
            pkgs.vscode-extensions.ms-python.vscode-pylance
            pkgs.firefox
            pkgs.alacritty
          ];

          # Auto install script to run upon boot
          system.activationScripts.autoInstall = {
            text = ''
              echo "Starting automated NixOS installation..."
              nixos-install --no-root-passwd << EOF
              rootPassword
              EOF
              echo "Installation complete. Rebooting..."
              reboot
            '';
          };
        })
      ];
    };
  };
}
