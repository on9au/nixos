{...}: {
  # Reachability canary.
  virtualisation.oci-containers.containers.whoami = {
    image = "traefik/whoami:v1.12.0";
    networks = ["proxy"];
    labels = {
      caddy = "whoami.jia.opena0.net";
      "caddy.reverse_proxy" = "{{upstreams 80}}";
    };
  };
}
