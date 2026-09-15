{config, ...}: {
  sops.secrets."uptime-kuma/password" = {};
  sops.secrets."uptime-kuma/username" = {};

  # Only setup-monitors.sh reads this; the service itself keeps its login in its database.
  sops.templates."uptime-kuma-admin.env".content = ''
    KUMA_PASSWORD=${config.sops.placeholder."uptime-kuma/password"}
    KUMA_USERNAME=${config.sops.placeholder."uptime-kuma/username"}
  '';

  virtualisation.oci-containers.containers.uptime-kuma = {
    image = "louislam/uptime-kuma:2";
    volumes = ["uptime-kuma_data:/app/data"];
    networks = ["proxy"];
    # For the terraria and beszel-agent monitors, which check ports on the host.
    extraOptions = ["--add-host=host.docker.internal:host-gateway"];
    labels = {
      caddy = "status.opena0.net";
      "caddy.reverse_proxy" = "{{upstreams 3001}}";
    };
  };
}
