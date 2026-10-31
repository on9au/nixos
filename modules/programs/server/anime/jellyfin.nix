{config, ...}: {
  virtualisation.oci-containers.containers.jellyfin = {
    image = "jellyfin/jellyfin:12.4";
    user = "2000:2000";
    environment.TZ = config.time.timeZone;
    ports = ["127.0.0.1:8096:8096"];
    volumes = [
      "/srv/anime:/anime:ro"
      "/var/lib/media/jellyfin/cache:/cache"
      "/var/lib/media/jellyfin/config:/config"
    ];
    # The UHD 620's QSV/VA-API, for phones that can't direct-play a release.
    devices = ["/dev/dri:/dev/dri"];
    extraOptions = ["--group-add=${toString config.users.groups.render.gid}"];
  };
}
