{...}: {
  virtualisation.oci-containers.containers.beszel = {
    image = "henrygd/beszel:0.18.7";
    volumes = ["beszel_data:/beszel_data"];
    networks = ["proxy"];
    extraOptions = ["--add-host=host.docker.internal:host-gateway"];
    labels = {
      caddy = "metrics.opena0.net";
      "caddy.reverse_proxy" = "{{upstreams 8090}}";
    };
  };

  # On the host rather than in a container, so it sees the battery, temperatures
  # and the physical disk. The module adds it to the docker group for container stats.
  services.beszel.agent = {
    enable = true;
    environment = {
      # The hub's public key, not a secret.
      KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICm2t+GkiwSc7awaztFQvDJgpHpHD4TXYMa/BRCKi0Pu";
      LISTEN = "45876";
    };
  };

  # The hub (and Kuma) reach the agent via host.docker.internal, which arrives
  # on the proxy network's bridge; nothing off-box needs the port.
  networking.firewall.interfaces.br-proxy.allowedTCPPorts = [45876];
}
