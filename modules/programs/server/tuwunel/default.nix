{
  config,
  lib,
  ...
}: {
  sops.secrets."tuwunel/oidc_client_secret" = {};
  sops.secrets."tuwunel/registration_token" = {};

  sops.templates."tuwunel.toml" = {
    content =
      lib.replaceStrings
      ["@OIDC_CLIENT_SECRET@" "@REGISTRATION_TOKEN@"]
      [
        config.sops.placeholder."tuwunel/oidc_client_secret"
        config.sops.placeholder."tuwunel/registration_token"
      ]
      (builtins.readFile ./tuwunel.toml);
    # The file is bind-mounted, so an edit only reaches tuwunel through a restart.
    restartUnits = ["docker-tuwunel.service"];
  };

  virtualisation.oci-containers.containers.tuwunel = {
    image = "jevolk/tuwunel:v1.9.3";
    environment.TUWUNEL_CONFIG = "/etc/tuwunel.toml";
    volumes = [
      "${config.sops.templates."tuwunel.toml".path}:/etc/tuwunel.toml:ro"
      # Appservice registrations, loaded at startup via appservice_dir.
      "/var/lib/homelab/tuwunel/appservices:/appservices:ro"
      "tuwunel_db:/var/lib/tuwunel"
    ];
    networks = ["proxy"];
    labels = {
      caddy = "matrix.opena0.net";
      "caddy.reverse_proxy" = "{{upstreams 6167}}";
    };
  };

  # tuwunel is root with no capabilities, and the registrations are mode 0600:
  # owned by anyone else they are unreadable, and every bridge's as_token is
  # refused. Reapplied each boot and switch: a restore brings back uid 1000.
  systemd.tmpfiles.settings."10-homelab"."/var/lib/homelab/tuwunel/appservices".Z = {
    group = "root";
    user = "root";
  };
}
