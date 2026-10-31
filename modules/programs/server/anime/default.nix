# Anime from nyaa: Seanime picks releases, qBittorrent fetches them through
# Mullvad, Jellyfin plays them. Tailnet only; see README.md.
{
  config,
  lib,
  ...
}: let
  # Published on 127.0.0.1 by the containers, served on the tailnet below.
  ports = {
    jellyfin = 8096;
    qbittorrent = 8080;
    seanime = 43211;
  };
in {
  imports = [
    ./gluetun.nix
    ./jellyfin.nix
    ./qbittorrent.nix
    ./seanime.nix
  ];

  # The containers run as this uid with --user, so it needs no shell or home.
  users.groups.media.gid = 2000;
  users.users.media = {
    group = "media";
    isSystemUser = true;
    uid = 2000;
  };

  # Outside /var/lib/homelab, so backup.sh leaves the library and the apps'
  # state alone.
  systemd.tmpfiles.settings."10-anime" = {
    "/srv/anime".d = {
      group = "media";
      mode = "0775";
      user = "media";
    };
    "/srv/manga/downloads".d = {
      group = "media";
      mode = "0775";
      user = "media";
    };
    "/srv/manga/local".d = {
      group = "media";
      mode = "0775";
      user = "media";
    };
    "/var/lib/media".d = {
      group = "root";
      mode = "0755";
      user = "root";
    };
    "/var/lib/media/jellyfin/cache".d = {
      group = "media";
      mode = "0750";
      user = "media";
    };
    "/var/lib/media/jellyfin/config".d = {
      group = "media";
      mode = "0750";
      user = "media";
    };
    "/var/lib/media/qbittorrent".d = {
      group = "media";
      mode = "0750";
      user = "media";
    };
    "/var/lib/media/seanime".d = {
      group = "media";
      mode = "0750";
      user = "media";
    };
  };

  # Plain HTTP inside WireGuard, so no tailnet HTTPS certificates are needed.
  # Reset first, so a port dropped here stops being served.
  systemd.services.anime-tailscale-serve = {
    description = "Serve Jellyfin, Seanime and qBittorrent on the tailnet";
    after = ["tailscaled.service" "tailscaled-set.service"];
    wants = ["tailscaled.service"];
    wantedBy = ["multi-user.target"];
    path = [config.services.tailscale.package];
    script =
      ''
        tailscale serve reset
      ''
      + lib.concatMapStrings (port: ''
        tailscale serve --bg --http=${toString port} http://127.0.0.1:${toString port}
      '') (lib.attrValues ports);
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # tailscaled answers before it has logged in.
      Restart = "on-failure";
      RestartSec = 10;
    };
  };
}
