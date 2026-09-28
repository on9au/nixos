# Daily restic backup of /home to R2. restic reads a read-only btrfs snapshot
# rather than the live tree, so the backup is one point in time; that needs
# /home and /.snapshots on the same btrfs filesystem (desktop and laptop layout).
{
  config,
  pkgs,
  ...
}: let
  # A fixed path, so each run finds the last snapshot as its parent and only
  # rescans what changed. Restores see files under this path, not /home.
  snapshot = "/.snapshots/restic/home";
  healthcheck = config.sops.secrets."backup/healthcheck_url".path;
  ping = path: ''curl -fsS -m 10 --retry 3 -o /dev/null "$(cat ${healthcheck})${path}" || true'';
in {
  sops.secrets."backup/aws_access_key_id" = {};
  sops.secrets."backup/aws_secret_access_key" = {};
  sops.secrets."backup/healthcheck_url" = {};
  sops.secrets."backup/restic_password" = {};
  sops.secrets."backup/restic_repository" = {};

  sops.templates."restic-r2.env".content = ''
    AWS_ACCESS_KEY_ID=${config.sops.placeholder."backup/aws_access_key_id"}
    AWS_SECRET_ACCESS_KEY=${config.sops.placeholder."backup/aws_secret_access_key"}
  '';

  services.restic.backups.r2 = {
    environmentFile = config.sops.templates."restic-r2.env".path;
    initialize = true;
    inhibitsSleep = true;
    passwordFile = config.sops.secrets."backup/restic_password".path;
    paths = [snapshot];
    repositoryFile = config.sops.secrets."backup/restic_repository".path;

    # Skips any directory holding a CACHEDIR.TAG: cargo's target/ and registry.
    extraBackupArgs = ["--exclude-caches"];
    exclude = [
      "${snapshot}/*/.cache"
      "${snapshot}/*/.cargo/git"
      "${snapshot}/*/.cargo/registry"
      "${snapshot}/*/.local/share/BeamNG"
      "${snapshot}/*/.local/share/nvim"
      "${snapshot}/*/.local/share/osu"
      "${snapshot}/*/.local/share/PrismLauncher"
      "${snapshot}/*/.local/share/Steam"
      "${snapshot}/*/.local/share/Trash"
      "${snapshot}/*/.npm"
      "${snapshot}/*/.rustup"
      "${snapshot}/*/.var/app/*/cache"
      "${snapshot}/*/.var/app/org.vinegarhq.Vinegar"
      "*.iso"
      ".direnv"
      "node_modules"
    ];

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 12"
    ];

    timerConfig = {
      OnCalendar = "daily";
      # The desktop is often off at midnight; a missed run fires on the next boot.
      Persistent = true;
      RandomizedDelaySec = "1h";
    };

    # A snapshot left behind by an interrupted run is replaced.
    backupPrepareCommand = ''
      ${ping "/start"}
      if [ -e ${snapshot} ]; then btrfs subvolume delete ${snapshot}; fi
      mkdir -p ${dirOf snapshot}
      btrfs subvolume snapshot -r /home ${snapshot}
    '';

    # Runs as ExecStopPost, so also after a failed prepare or backup.
    backupCleanupCommand = ''
      if [ -e ${snapshot} ]; then btrfs subvolume delete ${snapshot}; fi
      if [ "$SERVICE_RESULT" = success ]; then
        ${ping ""}
      else
        ${ping "/fail"}
      fi
    '';
  };

  systemd.services.restic-backups-r2.path = with pkgs; [btrfs-progs curl];
}
