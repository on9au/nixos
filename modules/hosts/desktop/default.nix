{pkgs, ...}: {
  # nix-style: ignore-order
  imports = [
    # Hardware
    ./hardware.nix
    ../../devices/apple-usb-c-dongle.nix
    ../../devices/aula-f87-pro.nix
    ../../hardware/cooling/coolercontrol.nix
    ../../hardware/drives/smart.nix
    ../../hardware/drives/udisks.nix
    ../../hardware/gpu/graphics.nix
    ../../hardware/gpu/radeon.nix
    ../../hardware/peripherals/bluetooth.nix
    ../../hardware/peripherals/keyd.nix
    ../../hardware/peripherals/printing.nix
    ../../hardware/peripherals/rgb
    ../../hardware/peripherals/tablet.nix
    ../../hardware/peripherals/yubikey

    # System
    ../../system
    ../../system/boot/lanzaboote.nix
    ../../system/envfs.nix
    ../../system/filesystems/btrfs.nix
    ../../system/filesystems/btrfs-snapshots.nix
    ../../system/network.nix
    ../../system/oomd.nix
    ../../system/tmpfs.nix
    ../../system/zram.nix

    # Users
    ../../users/djpro
    ../../home-manager

    # Desktop
    ../../programs/desktop/catppuccin
    ../../programs/desktop/fonts.nix
    ../../programs/desktop/fuzzel
    ../../programs/desktop/general
    ../../programs/desktop/greetd
    ../../programs/desktop/hyprland
    ../../programs/desktop/input-method.nix
    ../../programs/desktop/pipewire.nix
    ../../programs/desktop/swaync
    ../../programs/desktop/waybar

    # Services
    ../../programs/services/backup.nix
    ../../programs/services/kdeconnect.nix
    ../../programs/services/keyring
    ../../programs/services/mullvad.nix
    ../../programs/services/piper-tts.nix
    ../../programs/services/power-profiles-daemon.nix
    ../../programs/services/ssh-agent
    ../../programs/services/sshd.nix
    ../../programs/services/syncthing
    ../../programs/services/tailscale.nix

    # Apps
    ../../programs/apps/actual.nix
    ../../programs/apps/brave
    ../../programs/apps/creative.nix
    ../../programs/apps/discord.nix
    ../../programs/apps/everyday.nix
    ../../programs/apps/spotify.nix
    ../../programs/apps/winapps
    ../../programs/apps/wireshark.nix
    ../../programs/games

    # Servers
    ../../programs/server/minecraft

    # Shell and development
    ../../programs/development/claude-code
    ../../programs/development/neovim
    ../../programs/development/neovim/images
    ../../programs/development/neovim/lsp
    ../../programs/development/roblox
    ../../programs/development/toolchain
    ../../programs/tools
    ../../programs/tools/git
    ../../programs/tools/kitty
    ../../programs/tools/nh
    ../../programs/tools/nix-index
    ../../programs/tools/ssh
    ../../programs/tools/tmux
    ../../programs/tools/zsh
  ];

  networking.hostName = "DESKTOP-DYLAN";
  system.stateVersion = "26.05";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # The board's fan controller. Nothing loads it by itself, and without it the
  # CPU and case fans are invisible to Linux and CoolerControl.
  boot.kernelModules = ["nct6775"];

  boot.initrd.luks.devices."cryptroot".crypttabExtraOpts = ["fido2-device=auto"];

  swapDevices = [{device = "/swap/swapfile";}];

  # Nested subvolumes (/nix, /home, /srv, /swap) are not captured by a
  # snapshot of /, so /home and /srv (the Minecraft worlds) are taken
  # separately. btrbk won't create the target dirs.
  services.btrbk.instances.default.settings.subvolume = {
    "/".snapshot_dir = "/.snapshots/root";
    "/home".snapshot_dir = "/.snapshots/home";
    "/srv".snapshot_dir = "/.snapshots/srv";
  };

  systemd.tmpfiles.settings."btrbk-snapshot-dirs" = {
    "/.snapshots/root".d = {};
    "/.snapshots/home".d = {};
    "/.snapshots/srv".d = {};
  };

  sops.defaultSopsFile = ./secrets.yaml;

  greeterWallpaper = ./regreet-wallpaper.jpg;

  homeManagerModules = [
    {home.stateVersion = "26.05";}
  ];
}
