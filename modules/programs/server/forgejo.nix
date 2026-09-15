{config, ...}: {
  virtualisation.oci-containers.containers.forgejo = {
    image = "codeberg.org/forgejo/forgejo:16";
    environment = {
      FORGEJO__database__DB_TYPE = "sqlite3";
      FORGEJO__openid__ENABLE_OPENID_SIGNIN = "false";
      FORGEJO__openid__ENABLE_OPENID_SIGNUP = "true";
      FORGEJO__server__DOMAIN = "git.opena0.net";
      FORGEJO__server__HTTP_PORT = "3000";
      FORGEJO__server__ROOT_URL = "https://git.opena0.net/";
      FORGEJO__server__SSH_DOMAIN = "git.opena0.net";
      FORGEJO__server__SSH_LISTEN_PORT = "2222";
      FORGEJO__server__SSH_PORT = "22";
      FORGEJO__server__START_SSH_SERVER = "true";
      USER_GID = "1000";
      USER_UID = "1000";
    };
    ports = ["2222:2222"];
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
