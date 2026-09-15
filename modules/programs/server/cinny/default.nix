{...}: {
  virtualisation.oci-containers.containers.cinny = {
    image = "ghcr.io/cinnyapp/cinny:latest";
    volumes = ["${./config.json}:/app/config.json:ro"];
    networks = ["proxy"];
    labels = {
      caddy = "chat.opena0.net";
      "caddy.reverse_proxy" = "{{upstreams 80}}";
    };
  };
}
