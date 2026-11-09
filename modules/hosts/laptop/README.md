# LAPTOP-ON9AU

- `Model`: Dell MA16250
- `CPU`: Intel Ultra Core 9 285H (vPRO Enterprise)
- `RAM`: 64 GB
- `SSD`: 2 TB
- `GPU`: Intel Arc 140T, and an NVIDIA RTX PRO 2000 with no outputs, for
  render offload (`prime-run <program>`)

Dual-boots BitLocker-sealed Windows, which also runs the
[WSL host](../wsl/README.md).

- [`install.md`](install.md): the 2026-09 EndeavourOS → NixOS install, LUKS +
  TPM2, Secure Boot. Read it before touching the partition table, Secure
  Boot or the firmware: each of those can trip BitLocker's recovery.
- [`nvme-vmd-stalls.md`](nvme-vmd-stalls.md): the whole-machine freezes, the
  patched `vmd` driver that mitigates them, and the kernel-parameter stopgap
  that backs it up. Read it before a kernel bump — the patch is gated to one
  kernel series and fails the build on the next.
- Why the compositor sees only the iGPU, and the `AQ_DRM_DEVICES` trap: the
  `LAPTOP-ON9AU` block in
  [`uwsm/env`](../../programs/desktop/hyprland/config/uwsm/env).
