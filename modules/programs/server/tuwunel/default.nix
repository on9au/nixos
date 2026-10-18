{
  config,
  lib,
  pkgs,
  ...
}: {
  # kanidm-provision reads it to set the client's secret.
  sops.secrets."tuwunel/oidc_client_secret" = {
    owner = "kanidm";
    restartUnits = ["kanidm.service"];
  };

  services.kanidm.provision = {
    groups.tuwunel_admins = {};
    groups.tuwunel_users = {};
    systems.oauth2.tuwunel = {
      basicSecretFile = config.sops.secrets."tuwunel/oidc_client_secret".path;
      displayName = "Tuwunel";
      # tuwunel has no logo of its own. matrix.org's favicon rather than its
      # branding icon, which is plain black and vanishes on a dark page.
      imageFile = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/matrix-org/matrix.org/44f13b22050ecedeff65493af7bc0447669cc164/static/assets/favicon.svg";
        hash = "sha256-s2aBHsPuRsT4PCyVxIYvvrwqkyLQvlDNNPU7lAh13lY=";
      };
      originLanding = "https://matrix.opena0.net/";
      originUrl = "https://matrix.opena0.net/_matrix/client/unstable/login/sso/callback/tuwunel";
      # userid_claims in tuwunel.toml takes preferred_username first: turning
      # this off would give every Matrix user a new ID.
      preferShortUsername = true;
      scopeMaps.tuwunel_admins = ["email" "openid" "profile"];
      scopeMaps.tuwunel_users = ["email" "openid" "profile"];
      supplementaryScopeMaps.tuwunel_admins = ["admin"];
    };
  };

  sops.templates."tuwunel.toml" = {
    content =
      lib.replaceStrings
      ["@OIDC_CLIENT_SECRET@"]
      [
        config.sops.placeholder."tuwunel/oidc_client_secret"
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
      # A browser opening the bare name gets the web client rather than
      # tuwunel's placeholder. Only the exact path: /_matrix/… still proxies.
      "caddy.redir" = "/ https://chat.opena0.net/";
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
