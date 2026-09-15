# LAPTOP-ON9AU

- `Model`: Dell MA16250
- `CPU`: Intel Ultra Core 9 285H (vPRO Enterprise)
- `RAM`: 64 GB
- `SSD`: 2 TB
- `GPU`: See below

## Hybrid graphics (laptop)

The laptop has an Intel Arc 140T iGPU and an NVIDIA RTX PRO 2000. **Every
display connector is wired to the Intel side** — the panel, HDMI and USB-C —
and the NVIDIA card has no outputs at all; it exists for render offload.

`uwsm/env` therefore pins the compositor to the iGPU:

```sh
_igpu=$(readlink -f /dev/dri/by-path/pci-0000:00:02.0-card 2>/dev/null || true)
if [ -c "$_igpu" ]; then
    export AQ_DRM_DEVICES="$_igpu"
fi
unset _igpu
```

That has to be set before the compositor starts, so it belongs in `uwsm/env`
and not in `hypr/env.lua` — by the time `hl.env()` runs, aquamarine has already
chosen its devices. It is also why that block is keyed on the hostname: the
same line on a machine without that PCI device would leave the compositor with
no card to open.

**Do not write the `by-path` symlink into that variable directly.** It looks
like the obvious thing to do — the PCI address is the stable name, and the
`cardN` minors move between boots here — but `AQ_DRM_DEVICES` is a
**colon-separated list**, and every PCI address contains colons. The symlink is
not read as one device, it is split into three that do not exist:

```
drm: Explicit device list /dev/dri/by-path/pci-0000:00:02.0-card
ERR drm: Failed to canonicalize path /dev/dri/by-path/pci-0000
ERR drm: Failed to canonicalize path 00
ERR drm: Failed to canonicalize path 02.0-card
ERR drm: Found no gpus to use, cannot continue
```

Hyprland then aborts in `CBackend::create()` before reading any monitor config,
and the session drops straight back to the greeter — with `--verify-config`
still reporting the config as fine, because the config *is* fine. No escaping
helps; the colon is the delimiter. Resolving the symlink at login gets both
properties: the lookup is by PCI address and happens fresh each session, and
what aquamarine receives is a single colon-free path.

The `if [ -c ... ]` guard matters too: an empty `AQ_DRM_DEVICES` means "use no
devices", not "use all of them", and fails exactly the same way.

With only the iGPU opened, the NVIDIA card can runtime-suspend to D3cold for
the whole session instead of idling:

```bash
cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status   # -> suspended
```

Under KDE this reads `active` regardless, because KWin opens both cards. Use
`prime-run <program>` for anything that actually wants the NVIDIA card.

**Do not** add `GBM_BACKEND` or `__GLX_VENDOR_LIBRARY_NAME`. Those configure
the opposite arrangement — NVIDIA driving the display — and would break this
one.

The whole-machine freezes are a separate write-up: [nvme-vmd-stalls.md](nvme-vmd-stalls.md).
