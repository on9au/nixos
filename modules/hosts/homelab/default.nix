# jia-opena0: the homelab server, migrated from Debian. Headless.
# Generate the hardware config during the install, then git add it:
#   nixos-generate-config --root /mnt --show-hardware-config > modules/hosts/homelab/hardware.nix
{
  config,
  lib,
  ...
}: {
  # nix-style: ignore-order
  imports = [
    # Hardware
    ./hardware.nix
    ../../devices/zenbook-ux433fn.nix
    ../../hardware/power/always-on.nix

    # System
    ../../system
    ../../system/boot/systemd-boot.nix
    ../../system/hardening.nix
    ../../system/network-server.nix
    ../../system/zram.nix

    # Users
    ../../users/opena0
    ../../home-manager

    # Services
    ../../programs/services/sshd.nix
    ../../programs/services/tailscale.nix

    # Server
    ../../programs/server/actual
    ../../programs/server/anime
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
    ../../programs/server/open-webui.nix
    ../../programs/server/socket-proxy.nix
    ../../programs/server/syncthing.nix
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

  # sshd for Tailscale and the LAN only, not for containers.
  services.openssh.openFirewall = false;
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [7456];
  networking.firewall.extraCommands = "iptables -A nixos-fw -p tcp -s 192.168.1.0/24 --dport 7456 -j nixos-fw-accept";

  # Outbound traffic leaves through the proxy VPS, so federation and the like
  # never see the home IP. Fails closed: with the proxy down, jia has no
  # internet. LAN access keeps the router's DNS and LAN SSH.
  services.tailscale.useRoutingFeatures = "client";
  services.tailscale.extraSetFlags = [
    "--exit-node-allow-lan-access"
    "--exit-node=proxy-jia-opena0"
  ];

  # Ahead of Tailscale's rules, which start at 5210. The first keeps the LAN
  # and docker bridges off the exit node: Tailscale's own exceptions for them
  # are throw routes in its table, which networkd deletes as foreign routes
  # when it reconfigures this link. The second is the docker `vpn` network,
  # where gluetun alone sits: its Mullvad tunnel leaves from the home IP, so
  # torrents never cross the VPS's transfer allowance.
  systemd.network.networks."30-lan".routingPolicyRules = [
    {
      Priority = 5200;
      SuppressPrefixLength = 0;
      Table = "main";
    }
    {
      From = "10.200.0.0/24";
      Priority = 5201;
      Table = "main";
    }
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  # Overrides network-server.nix's DHCP.
  systemd.network.networks."30-lan" = {
    matchConfig.Name = "!veth*";
    matchConfig.Type = "ether";
    address = ["192.168.1.247/24"];
    dns = ["192.168.1.1"];
    gateway = ["192.168.1.1"];
    linkConfig.RequiredForOnline = "routable";
  };

  # Root takes the sudo password here: opena0 is not in the docker group, and
  # the wheel shortcuts the desktops get (system/nix/nix.nix, system/sudo.nix)
  # are undone.
  nix.settings.trusted-users = lib.mkForce ["root"];
  security.sudo.extraConfig = lib.mkAfter "Defaults timestamp_timeout=5";

  # Users and passwords come from here alone; a passwd run on the box is
  # undone by the next switch. The hash is in sops, so a new password is
  # `mkpasswd -m yescrypt` into opena0/password_hash.
  sops.secrets."opena0/password_hash".neededForUsers = true;
  users.mutableUsers = false;
  users.users.opena0.hashedPasswordFile = config.sops.secrets."opena0/password_hash".path;

  homeManagerModules = [
    {home.stateVersion = "26.11";}
  ];
}
