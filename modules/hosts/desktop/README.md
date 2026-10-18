# DESKTOP-DYLAN

basically the main machine.

- `CPU`: Intel i5-13600KF
- `RAM`: 2x16 GB DDR4-3600
- `GPU`: RX 9070 XT
- `SSD`: KC3000 2048 GB

## Secrets

[`secrets.yaml`](secrets.yaml); the workflow is in the
[top-level README](../../../README.md#secrets). The desktop runs no sshd, so
nothing generates a host key: it was made by hand once
(`sudo ssh-keygen -t ed25519 -N "" -C "" -f /etc/ssh/ssh_host_ed25519_key`)
and sops-nix is pointed at it. Its recipient is `&desktop-dylan`.

| Key | Used by |
| --- | --- |
| `backup/restic_repository`, `backup/restic_password` | restic; the password also lives in Bitwarden |
| `backup/aws_access_key_id`, `backup/aws_secret_access_key` | R2, a token scoped to this host's bucket |
| `backup/healthcheck_url` | backup check on healthchecks.io |

## Backups

btrbk's hourly snapshots in `/.snapshots` are for undoing a mistake, not a
backup: they share the disk and the LUKS header with what they protect.

[`programs/services/backup.nix`](../../programs/services/backup.nix) is the
backup: restic → R2, daily (`Persistent`, so a day the desktop was off runs on
the next boot), reporting to healthchecks.io. Retention 7 daily / 4 weekly /
12 monthly. restic reads a read-only snapshot at `/.snapshots/restic/home`,
taken for the run and deleted after, so paths in the repository start there.

Left out: caches, anything with a `CACHEDIR.TAG` (cargo's `target/`),
`node_modules`, games' data and `*.iso`.

```
sudo systemctl start restic-backups-r2        # run now
journalctl -u restic-backups-r2
sudo restic-r2 snapshots                       # wrapper with the unit's environment
sudo restic-r2 restore latest --target /tmp/restore \
  --include /.snapshots/restic/home/djpro/Documents
```
