{
  config,
  pkgs,
  ...
}: let
  # Without a password, Seanime trusts any private or Tailscale address with
  # everything, including settings that run programs. It has no environment
  # variable for one, and writes the flag's value into config.toml.
  start = pkgs.writeShellScript "seanime-start" ''
    exec ${pkgs.seanime}/bin/seanime --password "$(< /run/secrets/seanime_password)"
  '';

  # Built from nixpkgs: the only published image is a third party's, built
  # from floating base tags.
  image = pkgs.dockerTools.streamLayeredImage {
    name = "homelab-seanime";
    contents = [pkgs.cacert];
    extraCommands = "mkdir -m 1777 tmp";
    config = {
      Cmd = ["${start}"];
      Env = [
        "HOME=/data"
        "SEANIME_DATA_DIR=/data"
        # Published through gluetun, so it must listen beyond loopback.
        "SEANIME_SERVER_HOST=0.0.0.0"
        "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      ];
    };
  };
in {
  sops.secrets."seanime/password" = {
    owner = "media";
    restartUnits = ["docker-seanime.service"];
  };

  # In gluetun's namespace too: searching nyaa goes through Mullvad, and
  # qBittorrent is on localhost.
  virtualisation.oci-containers.containers.seanime = {
    image = "${image.imageName}:${image.imageTag}";
    imageStream = image;
    user = "2000:2000";
    # Manga goes over Seanime's default manga paths in /data, which only
    # config.toml can change, so it sits with the library rather than the
    # app's state.
    volumes = [
      "${config.sops.secrets."seanime/password".path}:/run/secrets/seanime_password:ro"
      "/srv/anime:/anime"
      "/srv/manga/downloads:/data/manga"
      "/srv/manga/local:/data/manga-local"
      "/var/lib/media/seanime:/data"
    ];
    dependsOn = ["gluetun"];
    extraOptions = ["--network=container:gluetun"];
    # Built by Nix, so there is no registry tag for Diun to compare against.
    labels."diun.enable" = "false";
  };
}
