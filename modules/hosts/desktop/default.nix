{...}: {
  # nix-style: ignore-order
  imports = [
    # Hardware
    ./hardware.nix
    ../../devices/apple-usb-c-dongle.nix
    ../../devices/aula-f87-pro.nix
    ../../hardware/drives/smart.nix
    ../../hardware/gpu/graphics.nix
    ../../hardware/gpu/radeon.nix
    ../../hardware/peripherals/bluetooth.nix
    ../../hardware/peripherals/keyd.nix
    ../../hardware/peripherals/printing.nix
    ../../hardware/peripherals/rgb.nix
    ../../hardware/peripherals/tablet.nix
    ../../hardware/peripherals/yubikey

    # System
    ../../system
    ../../system/boot/lanzaboote.nix
    ../../system/filesystems/btrfs.nix
    ../../system/filesystems/btrfs-snapshots.nix
    ../../system/network.nix
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
    ../../programs/services/kdeconnect.nix
    ../../programs/services/keyring.nix
    ../../programs/services/mullvad.nix
    ../../programs/services/piper-tts.nix
    ../../programs/services/power-profiles-daemon.nix
    ../../programs/services/ssh-agent
    ../../programs/services/tailscale.nix

    # Apps
    ../../programs/apps/creative.nix
    ../../programs/apps/discord.nix
    ../../programs/apps/everyday.nix
    ../../programs/apps/spotify.nix
    ../../programs/apps/winapps
    ../../programs/games

    # Shell and development
    ../../programs/development/claude-code
    ../../programs/development/neovim
    ../../programs/development/neovim/images
    ../../programs/development/neovim/lsp
    ../../programs/development/toolchain
    ../../programs/tools
    ../../programs/tools/git
    ../../programs/tools/kitty
    ../../programs/tools/nh
    ../../programs/tools/ssh
    ../../programs/tools/tmux
    ../../programs/tools/zsh
  ];

  networking.hostName = "DESKTOP-DYLAN";
  system.stateVersion = "26.05";

  # systemd in initrd - required for FIDO2 LUKS unlock later
  boot.initrd.systemd.enable = true;
  boot.initrd.luks.devices."cryptroot".crypttabExtraOpts = ["fido2-device=auto"];

  swapDevices = [{device = "/swap/swapfile";}];

  # Nested subvolumes (/nix, /home, /swap) are not captured by a snapshot of
  # /, so /home is taken separately. btrbk won't create the target dirs.
  services.btrbk.instances.default.settings.subvolume = {
    "/".snapshot_dir = "/.snapshots/root";
    "/home".snapshot_dir = "/.snapshots/home";
  };

  systemd.tmpfiles.settings."btrbk-snapshot-dirs" = {
    "/.snapshots/root".d = {};
    "/.snapshots/home".d = {};
  };

  greeterWallpaper = ./regreet-wallpaper.jpg;

  homeManagerModules = [
    {home.stateVersion = "26.05";}
  ];
}
