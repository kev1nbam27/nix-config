# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # You can import other NixOS modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/nixos):
    # outputs.nixosModules.example

    # Or modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-z
    inputs.sops-nix.nixosModules.sops

    # You can also split up your configuration and import pieces of it here:
    # ./users.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix
    # Import home-manager's NixOS module
    inputs.home-manager.nixosModules.home-manager

    ../modules/user-config
    ./impermanence.nix
  ];

  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    secrets = {
      "pcloud/access_token" = { };
      "pcloud/password" = { };
      "user_password".neededForUsers = true;
    };
    templates = {
      "rclone.conf".content = ''
        [pcloud]
        type = pcloud
        hostname = api.pcloud.com
        token = {"access_token":"${config.sops.placeholder."pcloud/access_token"}","token_type":"bearer","expiry":"0001-01-01T00:00:00Z"}
      '';
    };
  };

  # backup can be triggered with sudo systemctl start restic-backups-pcloud.service
  services.restic.backups.pcloud = {
    repository = "rclone:pcloud:/nixpad-backups";
    initialize = true;
    rcloneConfigFile = "${config.sops.templates."rclone.conf".path}";
    passwordFile = "${config.sops.secrets."pcloud/password".path}";
    paths = [ "/home/${config.userConfig.username}/nixpad_backup" ];
  };

  home-manager = {
    extraSpecialArgs = { inherit inputs outputs; };
    users = {
      # Import your home-manager configuration
      ${config.userConfig.username} = import ../home-manager/home.nix;
    };
  };

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  # This will add each flake input as a registry
  # To make nix3 commands consistent with your flake
  nix.registry = (lib.mapAttrs (_: flake: {inherit flake;})) ((lib.filterAttrs (_: lib.isType "flake")) inputs);

  # This will additionally add your inputs to the system's legacy channels
  # Making legacy nix commands consistent as well, awesome!
  nix.nixPath = ["/etc/nix/path"];
  environment.etc =
    lib.mapAttrs'
    (name: value: {
      name = "nix/path/${name}";
      value.source = value.flake;
    })
    config.nix.registry;

  nix.settings = {
    # Enable flakes and new 'nix' command
    experimental-features = "nix-command flakes";
    # Deduplicate and optimize nix store
    auto-optimise-store = true;
    # Needed for internet access in the video-paper module
    sandbox = "relaxed";
  };

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Bootloader.
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = true;
  };

  boot.loader.efi.canTouchEfiVariables = true;

  boot.supportedFilesystems = [ "btrfs" ];

  # Grub theme
  boot.loader.grub.theme = pkgs.stdenv.mkDerivation {
	  pname = "distro-grub-themes";
	  version = "3.1";
	  src = pkgs.fetchFromGitHub {
		  owner = "AdisonCavani";
		  repo = "distro-grub-themes";
		  rev = "v3.1";
		  hash = "sha256-ZcoGbbOMDDwjLhsvs77C7G7vINQnprdfI37a9ccrmPs=";
	  };
	  installPhase = "cp -r customize/nixos $out";
  };

  boot.kernelPackages = pkgs.linuxKernel.packages.linux_zen; # use linux zen kernel

  networking.hostName = "nixpad"; # Define your hostname.
  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Zurich";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = false;
  };

  programs.dconf.enable = true; # required for gtk

  # TODO: Configure your system-wide user settings (groups, etc), add more users as needed.
  users.users = {
    # Without this user nixos doesn't parse my actual user config correctly and deletes the user instead. This just started happening out of nowhere, and I don't know how to fix it without this workaround.
    nix = {
      isNormalUser = true;
    };
    ${config.userConfig.username} = {
      # TODO: You can set an initial password for your user.
      # If you do, you can skip setting a root password by passing '--no-root-passwd' to nixos-install.
      # Be sure to change it (using passwd) after rebooting!
      # initialPassword = "changeme";
      hashedPasswordFile = config.sops.secrets."user_password".path;
      isNormalUser = true;
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = [
        # TODO: Add your SSH public key(s) here, if you plan on using SSH to connect
      ];
      # TODO: Be sure to add any other groups you need (such as networkmanager, audio, docker, etc)
      extraGroups = [ "networkmanager" "video" "network" "rfkill" "power" "lp" "wheel" ];
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    gh
  ];

  environment.pathsToLink = [ "/share/zsh" ]; # required for system packages autocomplete

  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
#    extraPackages = with pkgs; [
#      vaapiVdpau
#      libvdpau-va-gl
#    ];
  };

  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --user-menu --user-menu-min-uid 1000 -c Hyprland --time --issue --asterisks";
        user = "greeter";
      };
    };
  };

  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";

      #Optional helps save long term battery health
      START_CHARGE_THRESH_BAT0 = 70; # 70 and bellow it starts to charge
      STOP_CHARGE_THRESH_BAT0 = 80; # 80 and above it stops charging
    };
  };


  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    hostKeys = [
      {
        path = "/persist/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "/persist/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.storageDriver = "btrfs";

  networking.firewall = {
    allowedTCPPorts = [ 22 ]; # ssh
    # wireguard trips rpfilter up
    checkReversePath = false;
   #  # if packets are still dropped, they will show up in dmesg
   #  logReversePathDrops = true;
   #  # wireguard trips rpfilter up
   #  extraCommands = ''
   #   ip46tables -t mangle -I nixos-fw-rpfilter -p udp -m udp --sport 51820 -j RETURN
   #   ip46tables -t mangle -I nixos-fw-rpfilter -p udp -m udp --dport 51820 -j RETURN
   # '';
   #  extraStopCommands = ''
   #   ip46tables -t mangle -D nixos-fw-rpfilter -p udp -m udp --sport 51820 -j RETURN || true
   #   ip46tables -t mangle -D nixos-fw-rpfilter -p udp -m udp --dport 51820 -j RETURN || true
   # '';
  };
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
