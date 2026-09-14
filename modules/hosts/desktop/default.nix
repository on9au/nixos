{...}: {
  # nix-style: ignore-order
  imports = [
    # Hardware
    ./hardware.nix
    ../../devices/apple-usb-c-dongle.nix
    ../../hardware/gpu/graphics.nix
    ../../hardware/peripherals/bluetooth.nix
    ../../hardware/peripherals/keyd.nix
    ../../hardware/peripherals/printing.nix
    ../../hardware/peripherals/tablet.nix
    ../../hardware/peripherals/yubikey

    # System
    ../../system
    ../../system/boot/lanzaboote.nix
    ../../system/filesystems/btrfs.nix
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
    ../../programs/development/toolchain
    ../../programs/tools
    ../../programs/tools/git
    ../../programs/tools/kitty
    ../../programs/tools/tmux
    ../../programs/tools/zsh
  ];

  networking.hostName = "DESKTOP-DYLAN";
  system.stateVersion = "26.05";

  # ESP is shared with EndeavourOS
  boot.loader.timeout = 10;

  # systemd in initrd - required for FIDO2 LUKS unlock later
  boot.initrd.systemd.enable = true;
  boot.initrd.luks.devices."cryptroot".crypttabExtraOpts = ["fido2-device=auto"];

  swapDevices = [{device = "/swap/swapfile";}];

  greeterWallpaper = ./regreet-wallpaper.jpg;

  homeManagerModules = [
    {home.stateVersion = "26.05";}
  ];
}
