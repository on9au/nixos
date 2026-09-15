{
  config,
  pkgs,
  ...
}: {
  sops.secrets."backup/aws_access_key_id" = {};
  sops.secrets."backup/aws_secret_access_key" = {};
  sops.secrets."backup/healthcheck_url" = {};
  sops.secrets."backup/restic_password" = {};
  sops.secrets."backup/restic_repository" = {};

  # Handed to the restic container with --env-file, which reads values literally.
  sops.templates."restic.env".content = ''
    AWS_ACCESS_KEY_ID=${config.sops.placeholder."backup/aws_access_key_id"}
    AWS_SECRET_ACCESS_KEY=${config.sops.placeholder."backup/aws_secret_access_key"}
    RESTIC_PASSWORD=${config.sops.placeholder."backup/restic_password"}
    RESTIC_REPOSITORY=${config.sops.placeholder."backup/restic_repository"}
  '';

  systemd.services.homelab-backup = {
    description = "Nightly homelab restic backup";
    after = ["docker.service" "network-online.target"];
    wants = ["network-online.target"];
    # An empty box must not push a snapshot into the series it is about to restore from.
    unitConfig.ConditionPathExists = "/var/lib/homelab/.restored";
    path = [config.virtualisation.docker.package pkgs.curl];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/bin/sh ${./backup.sh}";
    };
  };

  systemd.timers.homelab-backup = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      # A run missed while the box was down fires on the next boot.
      Persistent = true;
    };
  };
}
