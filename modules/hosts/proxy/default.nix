# proxy-jia-opena0: a VPS fronting the homelab over Tailscale. Not built yet.
{...}: {
  # nix-style: ignore-order
  imports = [
    # Hardware
    ./hardware.nix

    # System
    # UEFI, which every current VPS provider offers. A BIOS-only image needs
    # boot.loader.grub.devices instead -- see README.md.
    ../../system/boot/systemd-boot.nix
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

  # The reverse proxy itself goes in programs/server/ once the box exists.

  users.users.opena0.openssh.authorizedKeys.keys = [
  ];

  homeManagerModules = [
    {home.stateVersion = "26.11";}
  ];
}
