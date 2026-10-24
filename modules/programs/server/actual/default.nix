{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./ai
    ./up-import
  ];

  # kanidm-provision reads it to set the client's secret.
  sops.secrets."actual/oidc_client_secret" = {
    owner = "kanidm";
    restartUnits = ["kanidm.service"];
  };

  services.kanidm.provision = {
    groups.actual_users = {};
    systems.oauth2.actual = {
      basicSecretFile = config.sops.secrets."actual/oidc_client_secret".path;
      displayName = "Actual Budget";
      # Actual's openid-client only accepts RS256 ID tokens; Kanidm signs ES256
      # unless this is set.
      enableLegacyCrypto = true;
      imageFile = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/actualbudget/actual/v26.10.0/packages/desktop-client/public/android-chrome-512x512.png";
        hash = "sha256-8vxKOL6N8xi0t2Mbh1T/0dkZYxu9KrTnsw3ghdZLBrw=";
      };
      originLanding = "https://budget.opena0.net";
      originUrl = "https://budget.opena0.net/openid/callback";
      # preferred_username is Actual's user name, so this has to stay put:
      # flipping it gives everyone a new, empty account.
      preferShortUsername = true;
      scopeMaps.actual_users = ["email" "openid" "profile"];
    };
  };

  # An --env-file rather than ACTUAL_OPENID_CLIENT_SECRET_FILE: the secret is
  # owned by kanidm, and the container runs as uid 1001.
  sops.templates."actual.env" = {
    content = ''
      ACTUAL_OPENID_CLIENT_SECRET=${config.sops.placeholder."actual/oidc_client_secret"}
    '';
    restartUnits = ["docker-actual.service"];
  };

  virtualisation.oci-containers.containers.actual = {
    image = "actualbudget/actual-server:26.10.0";
    environment = {
      # Kanidm is the only login. With OpenID configured here, the server sets
      # it up on every start, before a password could be.
      ACTUAL_ALLOWED_LOGIN_METHODS = "openid";
      ACTUAL_LOGIN_METHOD = "openid";
      ACTUAL_OPENID_CLIENT_ID = "actual";
      ACTUAL_OPENID_DISCOVERY_URL = "https://idm.opena0.net/oauth2/openid/actual/.well-known/openid-configuration";
      ACTUAL_OPENID_ENFORCE = "true";
      ACTUAL_OPENID_SERVER_HOSTNAME = "https://budget.opena0.net";
      # The default never expires a session.
      ACTUAL_TOKEN_EXPIRATION = "86400";
      # Caddy's X-Forwarded-For, from its address on the proxy network. The
      # rate limiter keys on it.
      ACTUAL_TRUSTED_PROXIES = "172.16.0.0/12";
      # Anyone else in actual_users needs a user made for them first, by the
      # owner (the first to log in).
      ACTUAL_USER_CREATION_MODE = "manual";
    };
    environmentFiles = [config.sops.templates."actual.env".path];
    # The image runs as root but owns /data by its actual user, so a fresh
    # volume comes up owned by 1001.
    user = "1001:1001";
    volumes = ["actual_data:/data"];
    networks = ["proxy"];
    extraOptions = ["--read-only" "--tmpfs=/tmp"];
    labels = {
      caddy = "budget.opena0.net";
      # Bootstrap takes a password from anyone while the server has no login
      # method, which is the state it's left in if Kanidm was unreachable when
      # it started. OpenID never needs it.
      "caddy.@bootstrap.path" = "/account/bootstrap";
      "caddy.respond" = "@bootstrap 403";
      "caddy.reverse_proxy" = "{{upstreams 5006}}";
    };
  };
}
