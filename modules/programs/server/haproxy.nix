# The proxy VPS's public ports, passed through to jia over Tailscale as plain
# TCP, and the Minecraft servers' to the desktop. jia's Caddy still terminates
# TLS, so this box holds no certificates.
{
  config,
  lib,
  ...
}: let
  desktop = "desktop-dylan.tailc7b8fd.ts.net";
  jia = "jia-opena0.tailc7b8fd.ts.net";
  minecraft = import ./minecraft/servers.nix;
  minecraftPorts = lib.mapAttrsToList (_: server: server.port) minecraft;
in {
  services.haproxy = {
    enable = true;
    config = ''
      defaults
        mode tcp
        timeout connect 5s
        timeout client 1h
        timeout server 1h

      # MagicDNS answers only once tailscaled is up; init-addr none lets haproxy
      # start before that and pick the address up when it can.
      resolvers tailscale
        nameserver magicdns 100.100.100.100:53
        hold valid 60s

      # Plain: Caddy's automatic HTTP->HTTPS redirect server takes no listener
      # wrappers, so a PROXY header would break it.
      listen http
        bind :::80 v4v6
        server jia ${jia}:80 resolvers tailscale init-addr none

      listen https
        bind :::443 v4v6
        server jia ${jia}:443 send-proxy-v2 resolvers tailscale init-addr none

      # Forgejo advertises port 22 in clone URLs and listens on 2222.
      listen forgejo-ssh
        bind :::22 v4v6
        server jia ${jia}:2222 resolvers tailscale init-addr none

      listen terraria
        bind :::7777 v4v6
        server jia ${jia}:7777 resolvers tailscale init-addr none

      # lazymc holds these ports and can't read a PROXY header.
      ${lib.concatStrings (lib.mapAttrsToList (name: server: ''
          listen minecraft-${name}
            bind :::${toString server.port} v4v6
            server desktop ${desktop}:${toString server.port} resolvers tailscale init-addr none
        '')
        minecraft)}
    '';
  };

  # The module swaps /etc/haproxy.cfg on a switch but never tells haproxy, which
  # keeps the old listeners until it next restarts. A reload is hitless.
  systemd.services.haproxy.reloadTriggers = [config.environment.etc."haproxy.cfg".source];

  networking.firewall.allowedTCPPorts = [22 80 443 7777] ++ minecraftPorts;
}
