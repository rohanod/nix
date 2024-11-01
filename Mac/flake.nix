{
  description = "Rohan's Customized Darwin Configuration";

  inputs = {
    # Use a specific commit hash for better stability
    nixpkgs.url = "github:nixos/nixpkgs/24.05";
    
    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    homebrew-core = {
      url = "github:Homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:Homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nix-darwin, nix-homebrew, homebrew-core, homebrew-cask, ... }:
  let
    system = "aarch64-darwin";

    pkgs = import nixpkgs {
      inherit system;
      config = { 
        allowUnfree = true;
        allowUnsupportedSystem = false;
      };
    };
  in
  {
    darwinConfigurations.rohan = nix-darwin.lib.darwinSystem {
      inherit system;

      specialArgs = { inherit pkgs; };

      modules = [
        nix-homebrew.darwinModules.nix-homebrew

        ({ pkgs, config, lib, ... }: {
          # Enhanced Nix settings
          nix.settings = {
            experimental-features = [ "nix-command" "flakes" ];
            auto-optimise-store = true;
            trusted-users = [ "@admin" "rohan" ];
            max-jobs = 15;
            cores = 7;
            # Add substituters for faster downloads
            substituters = [
              "https://cache.nixos.org"
              "https://nix-community.cachix.org"
            ];
            trusted-public-keys = [
              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            ];
          };

          environment.systemPackages = [
            pkgs.tmux
            pkgs.mkalias
            pkgs.asciiquarium
            pkgs.curl
            pkgs.git
            pkgs.mas
            pkgs.pipx
            pkgs.go
            pkgs.alttab
            pkgs.vscode
            pkgs.vscode-extensions.github.copilot
            pkgs.vscode-extensions.github.copilot-chat
            pkgs.vscode-extensions.ms-python.vscode-pylance
            pkgs.vscode-extensions.bbenoist.nix
            pkgs.vscode-extensions.ms-python.python
            pkgs.vscode-extensions.ms-python.vscode-pylance
            pkgs.defaultbrowser
            pkgs.oh-my-zsh
            pkgs.zsh-autosuggestions
            # pkgs.vagrant
            pkgs.aria2
            pkgs.lilypond-with-fonts
            pkgs.timidity
            pkgs.ffmpeg
            pkgs.ariang
          ];

          system.activationScripts.fetchScreensaverFiles = ''
            if [ ! -d "$HOME/screensavers" ]; then
              git clone https://github.com/rjt11221/screensavers.git "$HOME/screensavers"
            fi
          '';

          # Consolidated applications script
          system.activationScripts.applications.text = let
            env = pkgs.buildEnv {
              name = "system-applications";
              paths = config.environment.systemPackages;
              pathsToLink = "/Applications";
            };
          in
            ''
              echo "setting up /Applications/Nix Apps..."
              rm -rf /Applications/Nix\ Apps
              mkdir -p /Applications/Nix\ Apps
              find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
              while read src; do
                app_name=$(basename "$src")
                ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
              done
            '';

          system.activationScripts.installPinokio.text = ''
            if [ ! -d "/Applications/Pinokio.app" ]; then
              curl -L https://github.com/pinokiocomputer/pinokio/releases/download/2.15.1/Pinokio-2.15.1-arm64.dmg -o /tmp/Pinokio-2.15.1-arm64.dmg
              hdiutil attach /tmp/Pinokio-2.15.1-arm64.dmg
              sudo cp -R /Volumes/Pinokio/Pinokio.app /Applications/
              hdiutil detach /Volumes/Pinokio
              rm /tmp/Pinokio-2.15.1-arm64.dmg
            fi
          '';

          system.activationScripts.installKekaHelper.text = ''
            if [ ! -d "/Applications/Keka Helper.app" ]; then
              sudo curl -L https://d.keka.io/helper -o /Applications/Keka\ Helper.zip
              sudo unzip /Applications/Keka\ Helper.zip -d /Applications/Keka\ Helper.app
              sudo rm /Applications/Keka\ Helper.zip
            fi
          '';

          system.activationScripts.installGPTMe.text = ''
            pipx install gptme || true
          '';

          system.activationScripts.setDefaultBrowser.text = ''
            osascript -e '
            on run
                do shell script "defaultbrowser velja"
                try
                    tell application "System Events"
                        tell application process "CoreServicesUIAgent"
                            tell window 1
                                tell (first button whose name starts with "use")
                                    perform action "AXPress"
                                end tell
                            end tell
                        end tell
                    end tell
                end try
            end run
            '
          '';

          homebrew = {
            enable = true;
            casks = [ 
              "brave-browser"
              "aerial"
              "docker"
              "chatgpt"
              "hovrly"
              "keyclu"
              "miniconda"
              "shottr"
              "mochi-diffusion"
              "mounty"
              "vmware-fusion"
              "tor-browser"
              "raspberry-pi-imager"
              "ultimaker-cura"
              "obs"
              "zed"
              "parsec"
              "twingate"
              "sigmaos"
              "google-chrome"
              "twingate"
              "parsec"
              "raycast"
              "spotify"
              "vagrant"
            ];
            brews = [
              "docker-compose"
              "create-dmg"
            ];
            masApps = {
              "Keka" = 470158793;
              "Surfshark VPN" = 1437809329;
              "Speediness" = 1596706466;
              "Online Check" = 6504709660;
              "Diffusers" = 1666309574;
              "Dropover" = 1355679052;
              "Hyperduck" = 6444667067;
              "Tapo" = 1472718009;
              "Deco" = 1186159417;
              "Draw Things" = 6444050820;
              "Localsend" = 1661733229;
              "Velja" = 1607635845;
              "Whatsapp" = 310633997;
              "Crystal Fetch" = 6454431289;
            };
            onActivation.cleanup = "zap";
          };

          services.nix-daemon.enable = true;

          # Enhanced display settings
          system.activationScripts.displaySettings.text = ''
            # Enable HiDPI display modes
            /usr/bin/defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true
            # Set dark mode
            /usr/bin/defaults write com.apple.systempreferences AppleInterfaceStyle -string "Dark"
            # Set display resolution if needed
            /usr/bin/defaults write com.apple.windowserver DisplayResolution -int 1680x1050 || true
          '';

          system.configurationRevision = self.rev or self.dirtyRev or null;
          system.stateVersion = 5;
        })

        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = "rohan";

            taps = {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
            };

            mutableTaps = false;
          };
        }
      ];
    };

    darwinPackages = self.darwinConfigurations.rohan.pkgs;
  };
}
