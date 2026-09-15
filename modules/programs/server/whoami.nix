{...}: {
  # Reachability canary.
  virtualisation.oci-containers.containers.whoami = {
    image = "traefik/whoami";
    networks = ["proxy"];
    labels = {
      caddy = "whoami.jia.opena0.net";
      "caddy.reverse_proxy" = "{{upstreams 80}}";
    };
  };
}
