{...}: {
  virtualisation.oci-containers.containers.cinny = {
    image = "ghcr.io/cinnyapp/cinny:v4.12.7";
    volumes = ["${./config.json}:/app/config.json:ro"];
    networks = ["proxy"];
    # nginx: the master chowns its cache directories and drops the workers to nginx.
    capabilities = {
      CHOWN = true;
      DAC_OVERRIDE = true;
      SETGID = true;
      SETUID = true;
    };
    labels = {
      caddy = "chat.opena0.net";
      "caddy.reverse_proxy" = "{{upstreams 80}}";
    };
  };
}
