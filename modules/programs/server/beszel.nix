{
  config,
  pkgs,
  ...
}: {
  # kanidm-provision reads it to set the client's secret. Beszel keeps its own
  # copy, entered once in PocketBase's admin UI.
  sops.secrets."beszel/oidc_client_secret" = {
    owner = "kanidm";
    restartUnits = ["kanidm.service"];
  };

  services.kanidm.provision = {
    groups.beszel_users = {};
    systems.oauth2.beszel = {
      basicSecretFile = config.sops.secrets."beszel/oidc_client_secret".path;
      displayName = "Beszel";
      imageFile = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/henrygd/beszel/v0.21.0/internal/site/public/static/icon.svg";
        hash = "sha256-oJD3AvKaxN2EVnrxwRnMaDP4rZYFlEk/dWX2RYkGtNM=";
      };
      originLanding = "https://metrics.opena0.net/";
      originUrl = "https://metrics.opena0.net/api/oauth2-redirect";
      scopeMaps.beszel_users = ["email" "openid" "profile"];
    };
  };

  virtualisation.oci-containers.containers.beszel = {
    image = "henrygd/beszel:0.21.0";
    # Kanidm's beszel_users decides who gets in, so a first login makes the
    # account. PocketBase superusers (/_/) keep their password login.
    environment = {
      DISABLE_PASSWORD_AUTH = "true";
      USER_CREATION = "true";
    };
    volumes = ["beszel_data:/beszel_data"];
    networks = ["proxy"];
    extraOptions = ["--add-host=host.docker.internal:host-gateway"];
    labels = {
      caddy = "metrics.opena0.net";
      "caddy.reverse_proxy" = "{{upstreams 8090}}";
    };
  };

  # On the host rather than in a container, so it sees the battery, temperatures
  # and the physical disk. The module adds it to the docker group for container stats.
  services.beszel.agent = {
    enable = true;
    environment = {
      # The hub's public key, not a secret.
      KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICm2t+GkiwSc7awaztFQvDJgpHpHD4TXYMa/BRCKi0Pu";
      LISTEN = "45876";
    };
  };

  # The hub (and Kuma) reach the agent via host.docker.internal, which arrives
  # on the proxy network's bridge; nothing off-box needs the port.
  networking.firewall.interfaces.br-proxy.allowedTCPPorts = [45876];
}
