# DESKTOP-DYLAN

basically the main machine.

- `CPU`: Intel i5-13600KF
- `RAM`: 2x16 GB DDR4-3600
- `GPU`: RX 9070 XT
- `SSD`: KC3000 2048 GB

## Disk and Windows

```
nvme0n1
├─p1  2 GiB   ESP, shared with Windows
├─p2          LUKS2 (FIDO2 + passphrase) → btrfs, subvolumes in hardware.nix
└─            ~256 GiB for Windows
```

The Secure Boot db has Microsoft's 2011 and 2023 CAs (`sbctl` enrolled them),
so Windows media boots without touching the keys, and sd-boot finds
`bootmgfw.efi` on the shared ESP by itself.

After installing Windows:

- Put Linux Boot Manager first again (firmware or `efibootmgr -o`); Windows
  takes the top spot.
- Save the BitLocker recovery key, or turn device encryption off.
- Turn off Fast Startup.
- Make Windows keep the RTC in UTC: `RealTimeIsUniversal` = 1 (DWORD) under
  `HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation`.

### Resizing p2

Each layer must stay no bigger than the one under it (btrfs ≤ LUKS ≤ p2), so
shrink past the target and grow back to fit. All online except the reboot:

```sh
sudo swapoff /swap/swapfile                  # btrfs can't move an active swapfile
sudo btrfs filesystem resize -<S+44>G /
sudo cryptsetup resize cryptroot --size $(( $(sudo blockdev --getsz /dev/mapper/cryptroot) - <S+24>*1024*1024*2 ))
sudo parted /dev/nvme0n1 -- resizepart 2 -<F>GiB   # the -- stops parted reading -N as a flag
reboot
sudo cryptsetup resize cryptroot             # fills p2
sudo btrfs filesystem resize max /
```

`<S>` is how many GiB p2 shrinks by, and `<F>` the free GiB after p2 once it
has (the free space there now plus `<S>`). Swap comes back on at boot.

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
exclusions are in the module. It covers `/home` and `/srv` (the Minecraft
worlds). restic reads read-only snapshots taken for the run, so paths in the
repository start at `/.snapshots/restic/home` and `/.snapshots/restic/srv`.

```
sudo systemctl start restic-backups-r2        # run now
journalctl -u restic-backups-r2
sudo restic-r2 snapshots                       # wrapper with the unit's environment
sudo restic-r2 restore latest --target /tmp/restore \
  --include /.snapshots/restic/home/djpro/Documents
```
