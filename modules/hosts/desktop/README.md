# DESKTOP-DYLAN

basically the main machine.

- `CPU`: Intel i5-13600KF
- `RAM`: 2x16 GB DDR4-3600
- `GPU`: RX 9070 XT
- `SSD`: KC3000 2048 GB

## Secrets

[`secrets.yaml`](secrets.yaml); the workflow is in the
[top-level README](../../../README.md#secrets). The host key predates sshd
here — it was made by hand once
(`sudo ssh-keygen -t ed25519 -N "" -C "" -f /etc/ssh/ssh_host_ed25519_key`) —
and sshd now serves that same file, so sops-nix finds it by default. Its
recipient is `&desktop-dylan`.

| Key | Used by |
| --- | --- |
| `backup/restic_repository`, `backup/restic_password` | restic; the password also lives in Bitwarden |
| `backup/aws_access_key_id`, `backup/aws_secret_access_key` | R2, a token scoped to this host's bucket |
| `backup/healthcheck_url` | backup check on healthchecks.io |

## Backups

btrbk's hourly snapshots in `/.snapshots` are for undoing a mistake, not a
backup: they share the disk and the LUKS header with what they protect.

[`programs/services/backup.nix`](../../programs/services/backup.nix) is the
backup: restic → R2, daily, reporting to healthchecks.io; retention and
exclusions are in the module. restic reads a read-only snapshot taken for the
run, so paths in the repository start at `/.snapshots/restic/home`.

```
sudo systemctl start restic-backups-r2        # run now
journalctl -u restic-backups-r2
sudo restic-r2 snapshots                       # wrapper with the unit's environment
sudo restic-r2 restore latest --target /tmp/restore \
  --include /.snapshots/restic/home/djpro/Documents
```
