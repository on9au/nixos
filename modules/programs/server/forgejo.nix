{
  config,
  pkgs,
  ...
}: {
  # No basicSecretFile: the client secret lives in forgejo's own database, as
  # the "kanidm" authentication source, and provisioning leaves it alone.
  services.kanidm.provision = {
    groups.forgejo_admins = {};
    groups.forgejo_users = {};
    systems.oauth2.forgejo = {
      displayName = "Forgejo";
      imageFile = pkgs.fetchurl {
        url = "https://codeberg.org/forgejo/forgejo/raw/tag/v17.0.1/public/assets/img/logo.svg";
        hash = "sha256-mXvqG5TJtApPWdRbEnEZpRs2Ttt9nWiQRdSpeHZznok=";
      };
      originLanding = "https://git.opena0.net/";
      originUrl = "https://git.opena0.net/user/oauth2/kanidm/callback";
      preferShortUsername = true;
      scopeMaps.forgejo_admins = ["email" "groups" "groups_name" "openid" "profile"];
      scopeMaps.forgejo_users = ["email" "groups" "groups_name" "openid" "profile"];
    };
  };

  virtualisation.oci-containers.containers.forgejo = {
    image = "codeberg.org/forgejo/forgejo:17.0.1";
    environment = {
      FORGEJO__database__DB_TYPE = "sqlite3";
      FORGEJO__openid__ENABLE_OPENID_SIGNIN = "false";
      FORGEJO__openid__ENABLE_OPENID_SIGNUP = "true";
      FORGEJO__server__DOMAIN = "git.opena0.net";
      FORGEJO__server__HTTP_PORT = "3000";
      FORGEJO__server__ROOT_URL = "https://git.opena0.net/";
      # git.opena0.net is behind Cloudflare's proxy, which carries no SSH;
      # jia.opena0.net is DNS-only and points at the proxy VPS.
      FORGEJO__server__SSH_DOMAIN = "jia.opena0.net";
      FORGEJO__server__SSH_LISTEN_PORT = "2222";
      FORGEJO__server__SSH_PORT = "22";
      FORGEJO__server__START_SSH_SERVER = "true";
      # Kanidm is the only web login: hides the password form and refuses its POST.
      # Git over SSH and access tokens are unaffected.
      FORGEJO__service__ENABLE_INTERNAL_SIGNIN = "false";
      USER_GID = "1000";
      USER_UID = "1000";
    };
    ports = ["2222:2222"];
    # The entrypoint chowns /data, then s6 runs forgejo as git and has to signal it.
    capabilities = {
      CHOWN = true;
      DAC_OVERRIDE = true;
      FOWNER = true;
      KILL = true;
      SETGID = true;
      SETUID = true;
    };
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "/etc/timezone:/etc/timezone:ro"
      "forgejo_data:/data"
    ];
    networks = ["proxy"];
    labels = {
      caddy = "git.opena0.net";
      "caddy.reverse_proxy" = "{{upstreams 3000}}";
    };
  };

  # NixOS has no /etc/timezone, and docker would mount an empty directory in its place.
  environment.etc.timezone.text = "${config.time.timeZone}\n";
}
