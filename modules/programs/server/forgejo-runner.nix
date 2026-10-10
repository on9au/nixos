{config, ...}: {
  sops.secrets."forgejo-runner/token" = {};

  # The public name, not forgejo:3000: jobs clone from the address the runner
  # registered with, and neither they nor the runner are on the proxy network.
  sops.templates."forgejo-runner.env".content = ''
    FORGEJO_INSTANCE_URL=https://git.opena0.net
    FORGEJO_RUNNER_TOKEN=${config.sops.placeholder."forgejo-runner/token"}
  '';

  # Jobs run on this daemon, not the host's: whoever controls the daemon a job
  # runs on is root wherever that daemon is. Rootless, so that is an
  # unprivileged user in this container.
  virtualisation.oci-containers.containers.forgejo-runner-dind = {
    image = "docker:29.9.0-dind-rootless";
    # Plain TCP on 2375; the runner is the only other thing on the network.
    environment.DOCKER_TLS_CERTDIR = "";
    # rootlesskit needs mounts and user namespaces the default profile denies,
    # and newuidmap is setuid.
    privileged = true;
    capabilities.ALL = null;
    extraOptions = ["--security-opt=no-new-privileges=false"];
    volumes = ["forgejo-runner_dind:/home/rootless/.local/share/docker"];
    networks = ["runner"];
    labels."diun.include_tags" = ''^\d+(\.\d+)+-dind-rootless$'';
  };

  virtualisation.oci-containers.containers.forgejo-runner = {
    image = "code.forgejo.org/forgejo/runner:13.2.0";

    # Registers on first start only; the .runner file it writes is what makes
    # this idempotent. Registration tokens are single-use, so re-registering
    # would need a fresh one.
    entrypoint = "/bin/sh";
    cmd = [
      "-ec"
      ''
        if [ ! -f /data/.runner ]; then
          forgejo-runner register --no-interactive \
            --instance "$FORGEJO_INSTANCE_URL" \
            --token "$FORGEJO_RUNNER_TOKEN" \
            --name jia \
            --labels docker:docker://node:22-bookworm
        fi
        exec forgejo-runner daemon --config /data/config.yml
      ''
    ];

    workdir = "/data";
    environment.DOCKER_HOST = "tcp://forgejo-runner-dind:2375";
    environmentFiles = [config.sops.templates."forgejo-runner.env".path];
    volumes = ["/var/lib/homelab/forgejo-runner/data:/data"];
    networks = ["runner"];
    dependsOn = ["forgejo-runner-dind"];
  };

  # The daemon exits if forgejo or dockerd isn't listening yet, and when they
  # restart together the default 100ms retry burns the start limit before it is.
  systemd.services.docker-forgejo-runner.serviceConfig.RestartSec = 5;
}
