{
  config,
  pkgs,
  ...
}: let
  caddy = pkgs.caddy.withPlugins {
    plugins = [
      "github.com/caddy-dns/cloudflare@v0.2.4"
      "github.com/lucaslorentz/caddy-docker-proxy/v2@v2.13.1"
    ];
    hash = "sha256-YmWHC5VH0+lF2fZBC6H3fO9Ahg+DfPFTJ4dh39IY3xQ=";
  };

  image = pkgs.dockerTools.streamLayeredImage {
    name = "homelab-caddy";
    contents = [pkgs.cacert];
    extraCommands = "mkdir -m 1777 tmp";
    config = {
      Cmd = ["${caddy}/bin/caddy" "docker-proxy"];
      Env = [
        "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
        "XDG_CONFIG_HOME=/config"
        "XDG_DATA_HOME=/data"
      ];
    };
  };
in {
  sops.secrets."caddy/acme_email" = {};
  sops.secrets."caddy/cloudflare_api_token" = {};

  sops.templates."caddy.env" = {
    content = ''
      ACME_EMAIL=${config.sops.placeholder."caddy/acme_email"}
      CLOUDFLARE_API_TOKEN=${config.sops.placeholder."caddy/cloudflare_api_token"}
    '';
    restartUnits = ["docker-caddy.service"];
  };

  virtualisation.oci-containers.containers.caddy = {
    image = "${image.imageName}:${image.imageTag}";
    imageStream = image;
    environment.CADDY_INGRESS_NETWORKS = "proxy";
    environmentFiles = [config.sops.templates."caddy.env".path];
    ports = [
      "443:443"
      "443:443/udp"
      "80:80"
    ];
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock:ro"
      "caddy_caddy_config:/config"
      "caddy_caddy_data:/data"
    ];
    networks = ["proxy"];

    labels = {
      "caddy.acme_dns" = "cloudflare {env.CLOUDFLARE_API_TOKEN}";
      # {$VAR} is substituted when caddy-docker-proxy parses its generated Caddyfile.
      "caddy.email" = "{$ACME_EMAIL}";
      # Built by Nix, so there is no registry tag for Diun to compare against.
      "diun.enable" = "false";
    };
  };
}
