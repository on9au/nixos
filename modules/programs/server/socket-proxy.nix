{...}: {
  # The docker API, GET only, for the containers that just read it: caddy
  # (labels) and diun (images). Mounting the socket itself is root on the host,
  # `:ro` or not. On its own network because inspecting a container returns its
  # environment, secrets included.
  virtualisation.oci-containers.containers.socket-proxy = {
    image = "ghcr.io/tecnativa/docker-socket-proxy:v0.5.0";
    environment = {
      CONTAINERS = "1";
      IMAGES = "1";
      INFO = "1";
      NETWORKS = "1";
    };
    volumes = ["/var/run/docker.sock:/var/run/docker.sock:ro"];
    networks = ["socket"];
  };
}
