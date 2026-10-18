{
  config,
  lib,
  pkgs,
  ...
}: let
  caddy = pkgs.caddy.withPlugins {
    plugins = [
      "github.com/caddy-dns/cloudflare@v0.2.4"
      "github.com/lucaslorentz/caddy-docker-proxy/v2@v2.13.1"
    ];
    hash = "sha256-2n1gTvFm7/bOn6T/fFBkL6tt1xjOZ093DbxcHz1UaP4=";
  };

  # https://www.cloudflare.com/ips/
  cloudflare = [
    "103.21.244.0/22"
    "103.22.200.0/22"
    "103.31.4.0/22"
    "104.16.0.0/13"
    "104.24.0.0/14"
    "108.162.192.0/18"
    "131.0.72.0/22"
    "141.101.64.0/18"
    "162.158.0.0/15"
    "172.64.0.0/13"
    "173.245.48.0/20"
    "188.114.96.0/20"
    "190.93.240.0/20"
    "197.234.240.0/22"
    "198.41.128.0/17"
    "2400:cb00::/32"
    "2405:8100::/32"
    "2405:b500::/32"
    "2606:4700::/32"
    "2803:f800::/32"
    "2a06:98c0::/29"
    "2c0f:f248::/32"
  ];

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
    environment = {
      CADDY_INGRESS_NETWORKS = "proxy";
      DOCKER_HOST = "tcp://socket-proxy:2375";
    };
    environmentFiles = [config.sops.templates."caddy.env".path];
    ports = [
      "443:443"
      "80:80"
    ];
    volumes = [
      "caddy_caddy_config:/config"
      "caddy_caddy_data:/data"
    ];
    networks = ["proxy" "socket"];
    dependsOn = ["socket-proxy"];
    extraOptions = ["--read-only" "--tmpfs=/tmp"];

    labels = {
      "caddy.acme_dns" = "cloudflare {env.CLOUDFLARE_API_TOKEN}";
      # {$VAR} is substituted when caddy-docker-proxy parses its generated Caddyfile.
      "caddy.email" = "{$ACME_EMAIL}";
      # Built by Nix, so there is no registry tag for Diun to compare against.
      "diun.enable" = "false";

      # The proxy VPS sends the client address in a PROXY header. Its
      # connections arrive from the proxy network's gateway, because Tailscale
      # masquerades what it forwards out of tailscale0 into a container. A
      # header from anywhere else is ignored.
      "caddy.servers.listener_wrappers.0_proxy_protocol.allow" = "172.18.0.1/32";
      "caddy.servers.listener_wrappers.1_tls" = "";
      # The proxy forwards TCP only, so no QUIC.
      "caddy.servers.protocols" = "h1 h2";
      # Orange-clouded names arrive with a Cloudflare edge as the client; the
      # visitor is in CF-Connecting-IP. Anyone else sending it is ignored.
      "caddy.servers.trusted_proxies" = "static ${lib.concatStringsSep " " cloudflare}";
      "caddy.servers.client_ip_headers" = "CF-Connecting-IP";
    };
  };
}
