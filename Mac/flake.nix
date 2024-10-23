{
  description = "Rohan's Customized Darwin Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
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
      config = { allowUnfree = true; };
    };
  in
  {
    darwinConfigurations.rohan = nix-darwin.lib.darwinSystem {
      inherit system;

      specialArgs = { inherit pkgs; };

      modules = [
        nix-homebrew.darwinModules.nix-homebrew

        ({ pkgs, config, lib, ... }: {
          environment.systemPackages = [
            pkgs.tmux
            pkgs.mkalias
            pkgs.python311Packages.ansible-core
            pkgs.asciiquarium
            pkgs.create-dmg
            pkgs.curl
            pkgs.git
            pkgs.mas
            pkgs.pipx
            pkgs.go
            pkgs.alttab
            pkgs.arc-browser
            pkgs.bartender
            pkgs.spotify
            pkgs.vscode
            pkgs.vscode-extensions.github.copilot
            pkgs.vscode-extensions.github.copilot-chat
            pkgs.vscode-extensions.ms-python.vscode-pylance
            pkgs.raycast
            pkgs.google-chrome
            pkgs.whatsapp-for-mac
            pkgs.defaultbrowser
            # pkgs.zed-editor
            pkgs.oh-my-zsh
            pkgs.iterm2
            pkgs.zsh-autosuggestions
            pkgs.fabric-ai
            pkgs.vagrant
          ];


          # Make aliases so I can search for apps from spotlight   
          system.activationScripts.applications.text = let
                  env = pkgs.buildEnv {
                    name = "system-applications";
                    paths = config.environment.systemPackages;
                    pathsToLink = "/Applications";
                  };
                in
                  pkgs.lib.mkForce ''
                    # Set up applications.
                    echo "setting up /Applications..." >&2
                    rm -rf /Applications/Nix\ Apps
                    mkdir -p /Applications/Nix\ Apps
                    find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
                    while read src; do
                      app_name=$(basename "$src")
                      echo "copying $src" >&2
                      ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
                    done
                  '';


          #Fetch Screensaver MP4 files
          system.activationScripts.fetchScreensaverFiles = ''
          echo "Fetching Screensaver files..."
          git clone https://github.com/rjt11221/screensavers.git
          '';



          # Pinokio installation script
          system.activationScripts.installPinokio.text = ''
            echo "Downloading and installing Pinokio Computer..."
            curl -L https://github.com/pinokiocomputer/pinokio/releases/download/2.15.1/Pinokio-2.15.1-arm64.dmg -o /tmp/Pinokio-2.15.1-arm64.dmg
            hdiutil attach /tmp/Pinokio-2.15.1-arm64.dmg
            sudo cp -R /Volumes/Pinokio/Pinokio.app /Applications/
            hdiutil detach /Volumes/Pinokio
            rm /tmp/Pinokio-2.15.1-arm64.dmg
            echo "Pinokio Computer installed successfully."
          '';

          # Install Keka Helper
          system.activationScripts.installKekaHelper.text = ''
          echo "Installing Keka Helper..."
          sudo curl -L https://d.keka.io/helper -o /Applications/Keka\ Helper.zip
          sudo unzip /Applications/Keka\ Helper.zip -d /Applications/Keka\ Helper.app
          sudo rm /Applications/Keka\ Helper.zip
          '';

          # Install GPTMe
          system.activationScripts.installGPTMe.text = ''
            echo "Installing GPTMe..."
            pipx install gptme || true
          '';

          # Make default browser Velja
          system.activationScripts.setDefaultBrowser.text = ''
          echo "Setting Velja as default browser..."
          osascript -e '
          on run
              -- Set Velja as the default browser
              do shell script "defaultbrowser velja"

              -- Try to interact with the UI button if it appears
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

          # homebrew = {
          #   enable = true;
          #   casks = [ 
          #     "brave-browser"
          #     "aerial"
          #     "docker"
          #     "chatgpt"
          #     "hovrly"
          #     "keyclu"
          #     "miniconda"
          #     "shottr"
          #     "mochi-diffusion"
          #     "mounty"
          #     "vmware-fusion"
          #     "tor-browser"
          #     "raspberry-pi-imager"
          #     "ultimaker-cura"
          #     "obs"
          #     "zed"
          #   ];
          #   brews = [
          #     "docker-compose"
          #   ];
          #   masApps = {
          #     "Keka" = 470158793;
          #     "Surfshark VPN" = 1437809329;
          #     "Speediness" = 1596706466;
          #     "Online Check" = 6504709660;
          #     "Diffusers" = 1666309574;
          #     "Dropover" = 1355679052;
          #     "Hyperduck" = 6444667067;
          #     "Tapo" = 1472718009;
          #     "Deco" = 1186159417;
          #     "Draw Things" = 6444050820;
          #     "Localsend" = 1661733229;
          #     "Velja" = 1607635845;
          #   };
          #   onActivation.cleanup = "zap";
          # };

          services.nix-daemon.enable = true;
          nix.settings.experimental-features = "nix-command flakes";

          system.activationScripts.displaySettings.text = ''
            echo "Setting display to 1680x1050 resolution..."
            /usr/bin/defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true
            /usr/bin/defaults write com.apple.systempreferences AppleInterfaceStyle -string "Dark"
            /usr/bin/defaults write com.apple.windowserver DisplayResolution -int 1680x1050
          '';

          system.configurationRevision = self.rev or self.dirtyRev or null;
          system.stateVersion = 5;

          system.activationScripts.applications.text = let
            env = pkgs.buildEnv {
              name = "system-applications";
              paths = config.environment.systemPackages;
              pathsToLink = "/Applications";
            };
          in
            lib.mkForce ''
              echo "Setting up /Applications/Nix Apps..." >&2
              rm -rf /Applications/Nix\ Apps
              mkdir -p /Applications/Nix\ Apps
              find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
              while read src; do
                app_name=$(basename "$src")
                echo "Copying $src to /Applications/Nix Apps/$app_name" >&2
                ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
              done
            '';
        })

        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = "rohan";
            autoMigrate = false;

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
