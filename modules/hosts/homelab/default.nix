# jia-opena0: the homelab server, migrated from Debian. Headless.
# Generate the hardware config during the install, then git add it:
#   nixos-generate-config --root /mnt --show-hardware-config > modules/hosts/homelab/hardware.nix
{...}: {
  # nix-style: ignore-order
  imports = [
    # Hardware
    ./hardware.nix
    ../../devices/zenbook-ux433fn.nix
    ../../hardware/power/always-on.nix

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

    # Server
    ../../programs/server/backup
    ../../programs/server/beszel.nix
    ../../programs/server/bridges
    ../../programs/server/caddy
    ../../programs/server/cinny
    ../../programs/server/diun.nix
    ../../programs/server/docker.nix
    ../../programs/server/forgejo-runner.nix
    ../../programs/server/forgejo.nix
    ../../programs/server/kanidm.nix
    ../../programs/server/liveness.nix
    ../../programs/server/terraria.nix
    ../../programs/server/tuwunel
    ../../programs/server/uptime-kuma
    ../../programs/server/whoami.nix

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

  sops.defaultSopsFile = ./secrets.yaml;

  # The router forwards 80, 443, 2222 and 7777 here. Overrides network-server.nix's DHCP.
  systemd.network.networks."30-lan" = {
    matchConfig.Type = "ether";
    address = ["192.168.1.247/24"];
    dns = ["192.168.1.1"];
    gateway = ["192.168.1.1"];
    linkConfig.RequiredForOnline = "routable";
  };

  users.users.opena0.extraGroups = ["docker"];

  homeManagerModules = [
    {home.stateVersion = "26.11";}
  ];
}
