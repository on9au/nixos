{config, ...}: {
  sops.secrets."gluetun/wireguard_addresses" = {};
  sops.secrets."gluetun/wireguard_private_key" = {};

  sops.templates."gluetun.env" = {
    content = ''
      WIREGUARD_ADDRESSES=${config.sops.placeholder."gluetun/wireguard_addresses"}
      WIREGUARD_PRIVATE_KEY=${config.sops.placeholder."gluetun/wireguard_private_key"}
    '';
    restartUnits = ["docker-gluetun.service"];
  };

  # qBittorrent and Seanime share this container's network namespace, so they
  # have no way out but the tunnel, and their ports are published here.
  virtualisation.oci-containers.containers.gluetun = {
    image = "qmcgaw/gluetun:v3.41.3";
    environment = {
      # Owner of the files it writes under /tmp/gluetun. Left at 1000, root
      # without DAC_OVERRIDE can't open them again.
      PGID = "0";
      PUID = "0";
      SERVER_CITIES = "Melbourne";
      TZ = config.time.timeZone;
      VPN_SERVICE_PROVIDER = "mullvad";
      VPN_TYPE = "wireguard";
      # The default, pinned because the egress rule below allows only this.
      WIREGUARD_ENDPOINT_PORT = "51820";
    };
    environmentFiles = [config.sops.templates."gluetun.env".path];
    ports = [
      "127.0.0.1:43211:43211"
      "127.0.0.1:8080:8080"
    ];
    # On its own subnet, which hosts/homelab routes out the home connection
    # rather than the exit node.
    networks = ["vpn"];
    # The tunnel and its kill-switch firewall, a DNS server on 53, and the
    # ICMP health check.
    capabilities = {
      NET_ADMIN = true;
      NET_BIND_SERVICE = true;
      NET_RAW = true;
    };
    devices = ["/dev/net/tun:/dev/net/tun"];
  };

  # gluetun's firewall is the kill switch; this backs it from the host. The
  # vpn network goes out the home connection, so only the WireGuard tunnel may
  # leave it. In mangle, which docker doesn't manage, so it holds across
  # docker restarts.
  networking.firewall.extraCommands = ''
    iptables -t mangle -N anime-vpn 2>/dev/null || iptables -t mangle -F anime-vpn
    iptables -t mangle -A anime-vpn -p udp --dport 51820 -j RETURN
    iptables -t mangle -A anime-vpn -j DROP
    iptables -t mangle -C FORWARD -i br-vpn ! -o br-vpn -j anime-vpn 2>/dev/null \
      || iptables -t mangle -A FORWARD -i br-vpn ! -o br-vpn -j anime-vpn
  '';
  networking.firewall.extraStopCommands = ''
    iptables -t mangle -D FORWARD -i br-vpn ! -o br-vpn -j anime-vpn 2>/dev/null || true
  '';
}
