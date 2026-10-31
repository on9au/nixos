{config, ...}: {
  virtualisation.oci-containers.containers.qbittorrent = {
    image = "qbittorrentofficial/qbittorrent-nox:5.3.0-2";
    # Started as non-root, the entrypoint skips its chown and user switch.
    user = "2000:2000";
    environment = {
      QBT_LEGAL_NOTICE = "confirm";
      QBT_WEBUI_PORT = "8080";
      TZ = config.time.timeZone;
    };
    # Seanime hands qBittorrent paths under /anime, so both mount it there.
    volumes = [
      "/srv/anime:/anime"
      "/var/lib/media/qbittorrent:/config"
    ];
    dependsOn = ["gluetun"];
    extraOptions = ["--network=container:gluetun"];
  };
}
