{
  config,
  pkgs,
  ...
}: let
  tls = "/var/lib/kanidm-tls";
in {
  # Provisioning runs when kanidm starts, so a changed secret restarts it.
  sops.secrets."kanidm/group_members" = {
    owner = "kanidm";
    restartUnits = ["kanidm.service"];
  };
  sops.secrets."kanidm/idm_admin_password" = {
    owner = "kanidm";
    restartUnits = ["kanidm.service"];
  };

  services.kanidm = {
    # The secret-provisioning patches let basicSecretFile and the idm_admin
    # password come from sops. Kanidm upgrades one minor version at a time.
    package = pkgs.kanidmWithSecretProvisioning_1_11;

    server.enable = true;
    server.settings = {
      # Caddy reaches it as host.docker.internal; the firewall below opens 8443 on br-proxy only.
      bindaddress = "[::]:8443";
      # Has to match the restored database. A different value makes the unit's
      # ExecStartPre rename the domain, which invalidates every passkey.
      domain = "idm.opena0.net";
      origin = "https://idm.opena0.net";
      # Caddy's X-Forwarded-For, from its address on the proxy network.
      http_client_address_info.x-forward-for = ["172.16.0.0/12"];
      tls_chain = "${tls}/chain.pem";
      tls_key = "${tls}/key.pem";
    };

    # Each service module declares its own groups and oauth2 client. Members,
    # and any persons, are in the kanidm/group_members secret so the public
    # repo doesn't list who has access. It's YAML (groups.<group>.members),
    # which yq merges into the JSON state.
    provision = {
      enable = true;
      extraJsonFile = config.sops.secrets."kanidm/group_members".path;
      idmAdminPasswordFile = config.sops.secrets."kanidm/idm_admin_password".path;
    };

    client.enable = true;
    client.settings.uri = "https://idm.opena0.net";
  };

  # A fresh database would start a new domain; see docker.nix.
  systemd.services.kanidm.unitConfig.ConditionPathExists = "/var/lib/homelab/.restored";

  # Browsers see Caddy's certificate, and Caddy doesn't verify this one, so it
  # only has to exist. `kanidmd cert-generate` makes one that expires in 5 days.
  systemd.services.kanidm-tls = {
    before = ["kanidm.service"];
    requiredBy = ["kanidm.service"];
    path = [pkgs.openssl];
    script = ''
      [ -s ${tls}/key.pem ] && exit 0
      install -d -m 0700 -o kanidm -g kanidm ${tls}
      openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 3650 \
        -subj /CN=idm.opena0.net \
        -addext subjectAltName=DNS:idm.opena0.net,DNS:localhost \
        -addext basicConstraints=critical,CA:FALSE \
        -addext keyUsage=critical,digitalSignature \
        -addext extendedKeyUsage=serverAuth \
        -keyout ${tls}/key.pem -out ${tls}/chain.pem
      chown kanidm:kanidm ${tls}/key.pem ${tls}/chain.pem
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
  };

  networking.firewall.interfaces.br-proxy.allowedTCPPorts = [8443];

  # caddy-docker-proxy builds sites from container labels, so a service on the
  # host gets its site as a label on caddy itself.
  virtualisation.oci-containers.containers.caddy = {
    extraOptions = ["--add-host=host.docker.internal:host-gateway"];
    labels = {
      caddy_1 = "idm.opena0.net";
      "caddy_1.reverse_proxy" = "https://host.docker.internal:8443";
      "caddy_1.reverse_proxy.transport" = "http";
      "caddy_1.reverse_proxy.transport.tls_insecure_skip_verify" = "";
    };
  };
}
