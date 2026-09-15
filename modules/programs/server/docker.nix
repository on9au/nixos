{
  config,
  lib,
  ...
}: {
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  systemd.tmpfiles.settings."10-homelab"."/var/lib/homelab".d = {
    group = "root";
    mode = "0755";
    user = "root";
  };

  systemd.services =
    {
      # Every container caddy routes to joins it. The fixed bridge name lets the
      # firewall single out containers talking to host services.
      docker-network-proxy = {
        after = ["docker.service"];
        requires = ["docker.service"];
        path = [config.virtualisation.docker.package];
        script = ''
          docker network inspect proxy >/dev/null 2>&1 \
            || docker network create --opt com.docker.network.bridge.name=br-proxy proxy
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };
    }
    # Nothing starts until the restore has run: tuwunel booting on an empty volume
    # mints a new federation signing key. See hosts/homelab/README.md.
    // lib.mapAttrs' (_: container:
      lib.nameValuePair container.serviceName {
        after = ["docker-network-proxy.service"];
        requires = ["docker-network-proxy.service"];
        unitConfig.ConditionPathExists = "/var/lib/homelab/.restored";
      })
    config.virtualisation.oci-containers.containers;
}
