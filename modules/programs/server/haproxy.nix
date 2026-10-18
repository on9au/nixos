# The proxy VPS's public ports, passed through to jia over Tailscale as plain
# TCP. jia's Caddy still terminates TLS, so this box holds no certificates.
{...}: let
  jia = "jia-opena0.tailc7b8fd.ts.net";
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
    '';
  };

  networking.firewall.allowedTCPPorts = [22 80 443 7777];
}
