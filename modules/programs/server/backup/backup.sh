#!/bin/sh
# Nightly backup of the homelab's stateful data into a restic repository.
#
# restic runs in a container so the paths inside the repository stay what they
# were on the macOS and Debian hosts -- /data/<volume> and /data/homelab -- and
# the retention policy keeps applying to one continuous series.
#
# tuwunel (RocksDB), forgejo, kanidm and the bridges (SQLite) all tear if their
# files are copied while running, so they are stopped for the snapshot -- about
# 30 seconds. They are systemd units, so they are stopped through systemctl: a
# bare `docker stop` would let the unit restart them mid-snapshot. The trap
# restarts them even if restic fails partway.
#
# Run as root. Credentials come from sops; see default.nix.
#
# Usage:
#   backup.sh              nightly backup, then prune to the retention policy
#   backup.sh init         create the repository (once)
#   backup.sh snapshots    ...or any other restic command, passed through

set -eu

RESTIC_ENV=/run/secrets/rendered/restic.env
HEALTHCHECK_URL=$(cat /run/secrets/backup/healthcheck_url)

STATEFUL="tuwunel forgejo kanidm uptime-kuma beszel \
  mautrix-telegram mautrix-whatsapp mautrix-discord \
  mautrix-gmessages mautrix-messenger mautrix-instagram"
VOLUMES="forgejo_data kanidm_data kanidm_certs tuwunel_db uptime-kuma_data beszel_data"

UNITS=""
for _c in $STATEFUL; do
  UNITS="$UNITS docker-$_c.service"
done

restic_run() {
  _mounts=""
  for _v in $VOLUMES; do
    _mounts="$_mounts -v $_v:/data/$_v:ro"
  done
  # shellcheck disable=SC2086
  docker run --rm --env-file "$RESTIC_ENV" \
    $_mounts \
    -v /var/lib/homelab:/data/homelab:ro \
    restic/restic "$@"
}

# Dead-man switch. Silence is the failure mode this guards against: if the
# machine is off, or the timer never fires, nothing here runs at all -- so the
# alert has to come from something off-box noticing the ping never arrived.
# Never fatal: a monitoring outage must not fail a backup that otherwise worked.
ping_hc() {
  curl -fsS -m 10 --retry 3 -o /dev/null "${HEALTHCHECK_URL}${1:-}" || true
}

case "${1:-backup}" in
backup)
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') backup starting ==="
  ping_hc /start
  # Stays armed through the prune, so a forget/prune failure also reports.
  # shellcheck disable=SC2086
  trap 'systemctl start $UNITS; ping_hc /fail' EXIT INT TERM
  # shellcheck disable=SC2086
  systemctl stop $UNITS

  # restic exits 3 when a source file could not be read. That is a warning, not
  # a failure -- the snapshot is still written -- so it must not abort the run
  # and skip the prune below. Anything else is fatal.
  set +e
  restic_run backup /data --tag nightly --host jia
  _rc=$?
  set -e
  case $_rc in
  0) ;;
  3) echo "WARNING: some files were unreadable; snapshot still written" ;;
  *) echo "restic backup failed (exit $_rc)"; exit $_rc ;;
  esac

  # shellcheck disable=SC2086
  systemctl start $UNITS
  restic_run forget --tag nightly --host jia \
    --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
  ping_hc
  trap - EXIT INT TERM
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') backup done ==="
  ;;
*)
  restic_run "$@"
  ;;
esac
