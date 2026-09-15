{config, ...}: {
  sops.secrets."forgejo-runner/token" = {};

  sops.templates."forgejo-runner.env".content = ''
    FORGEJO_INSTANCE_URL=http://forgejo:3000
    FORGEJO_RUNNER_TOKEN=${config.sops.placeholder."forgejo-runner/token"}
  '';

  virtualisation.oci-containers.containers.forgejo-runner = {
    image = "code.forgejo.org/forgejo/runner:12.0.0";

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
    environmentFiles = [config.sops.templates."forgejo-runner.env".path];

    # The image runs as uid 1000 but the socket is root:docker 0660. NixOS fixes
    # the docker GID, so this no longer drifts with each install.
    extraOptions = ["--group-add=${toString config.users.groups.docker.gid}"];

    volumes = [
      "/var/lib/homelab/forgejo-runner/data:/data"
      # Jobs run as sibling containers on the same daemon.
      "/var/run/docker.sock:/var/run/docker.sock"
    ];
    networks = ["proxy"];
  };
}
