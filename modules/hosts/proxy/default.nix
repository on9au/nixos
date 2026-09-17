# proxy-jia-opena0: a VPS fronting the homelab over Tailscale. Not built yet.
# Installed with nixos-anywhere; see README.md.
{...}: {
  # nix-style: ignore-order
  imports = [
    # Hardware
    ./disko.nix
    ./hardware.nix

    # System
    ../../system
    ../../system/network-server.nix
    ../../system/zram.nix

    # Users
    ../../users/opena0
    ../../home-manager

    # Services
    ../../programs/services/sshd.nix
    ../../programs/services/tailscale.nix

    # Shell and development
    ../../programs/development/neovim
    ../../programs/tools
    ../../programs/tools/git
    ../../programs/tools/nh
    ../../programs/tools/ssh
    ../../programs/tools/tmux
    ../../programs/tools/zsh
  ];

  networking.hostName = "proxy-jia-opena0";
  system.stateVersion = "26.11";

  # GRUB rather than systemd-boot, so one image boots on BIOS or UEFI. Installed
  # to the removable path, which needs no NVRAM entry and so conflicts with
  # efi.canTouchEfiVariables (set by system/boot/systemd-boot.nix).
  boot.loader.grub = {
    efiInstallAsRemovable = true;
    efiSupport = true;
  };

  # The reverse proxy itself goes in programs/server/ once the box exists.

  sops.defaultSopsFile = ./secrets.yaml;

  homeManagerModules = [
    {home.stateVersion = "26.11";}
  ];
}
