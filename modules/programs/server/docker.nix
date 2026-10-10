{
  config,
  lib,
  ...
}: let
  # `docker network create` options, by network.
  networks = {
    # Every container caddy routes to joins it. The fixed bridge name lets the
    # firewall single out containers talking to host services.
    proxy = "--opt com.docker.network.bridge.name=br-proxy";
    # The Actions runner and its own docker daemon, away from the services.
    runner = "";
    # socket-proxy and its readers; no route out.
    socket = "--internal";
  };

  networkUnits = map (name: "docker-network-${name}.service") (lib.attrNames networks);
in {
  # Containers start with no capabilities; a module adds back what its image needs.
  options.virtualisation.oci-containers.containers = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      capabilities.ALL = lib.mkDefault false;
    });
  };

  config = {
    virtualisation.docker.enable = true;
    virtualisation.docker.daemon.settings.no-new-privileges = true;
    virtualisation.oci-containers.backend = "docker";

    systemd.tmpfiles.settings."10-homelab"."/var/lib/homelab".d = {
      group = "root";
      mode = "0755";
      user = "root";
    };

    systemd.services =
      lib.mapAttrs' (name: options:
        lib.nameValuePair "docker-network-${name}" {
          after = ["docker.service"];
          requires = ["docker.service"];
          path = [config.virtualisation.docker.package];
          script = ''
            docker network inspect ${name} >/dev/null 2>&1 \
              || docker network create ${options} ${name}
          '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
        })
      networks
      # Nothing starts until the restore has run: tuwunel booting on an empty volume
      # mints a new federation signing key. See hosts/homelab/README.md.
      // lib.mapAttrs' (_: container:
        lib.nameValuePair container.serviceName {
          after = networkUnits;
          requires = networkUnits;
          unitConfig.ConditionPathExists = "/var/lib/homelab/.restored";
        })
      config.virtualisation.oci-containers.containers;
  };
}
