{config, ...}: let
  image = "qmcgaw/gluetun:v3.41.3";
in {
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
    image = image;
    environment = {
      SERVER_CITIES = "Melbourne";
      TZ = config.time.timeZone;
      # Below the default 0.8, which a shrinking Mullvad fails against the
      # list built into the image.
      UPDATER_MIN_RATIO = "0.5";
      # Refreshes /gluetun/servers.json through the tunnel; see gluetun-servers.
      UPDATER_PERIOD = "24h";
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
    volumes = ["/var/lib/media/gluetun:/gluetun"];
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
    # gluetun makes /tmp/gluetun mode 0644, which root can only enter with
    # the capabilities dropped above; an existing tmpfs is left alone.
    extraOptions = ["--tmpfs=/tmp/gluetun"];
  };

  # The server list built into the image goes stale as Mullvad retires relays,
  # and the updater above needs a working tunnel first. So every start gets a
  # fresh list, fetched outside the tunnel from Mullvad's API. A failed fetch
  # doesn't hold gluetun back: it falls back to the last list saved.
  systemd.services.gluetun-servers = {
    description = "Fetch gluetun's Mullvad server list";
    after = ["docker.service"];
    requires = ["docker.service"];
    before = ["docker-gluetun.service"];
    wantedBy = ["docker-gluetun.service"];
    path = [config.virtualisation.docker.package];
    script = ''
      docker run --rm --cap-drop=ALL -v /var/lib/media/gluetun:/gluetun \
        ${image} update -enduser -providers mullvad -minratio 0.5
    '';
    serviceConfig.Type = "oneshot";
  };

  systemd.tmpfiles.settings."10-anime"."/var/lib/media/gluetun".d = {
    group = "root";
    mode = "0700";
    user = "root";
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
