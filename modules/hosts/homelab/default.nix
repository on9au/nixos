# jia-opena0: the homelab server, migrated from Debian. Headless.
# Generate the hardware config during the install, then git add it:
#   nixos-generate-config --root /mnt --show-hardware-config > modules/hosts/homelab/hardware.nix
{...}: {
  # nix-style: ignore-order
  imports = [
    # Hardware
    ./hardware.nix

    # System
    ../../system
    ../../system/boot/systemd-boot.nix
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

  networking.hostName = "jia-opena0";
  system.stateVersion = "26.11";

  # Matches `Port 7456` in the jia block of programs/tools/ssh/home.nix.
  services.openssh.ports = [7456];

  # The YubiKey resident key's public half; `ssh-keygen -K` re-emits it on any
  # machine holding the token. sshd.nix asserts this is non-empty.
  users.users.opena0.openssh.authorizedKeys.keys = [
  ];

  homeManagerModules = [
    {home.stateVersion = "26.11";}
  ];
}
