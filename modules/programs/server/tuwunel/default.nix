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
    image = "jevolk/tuwunel:latest";
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
}
