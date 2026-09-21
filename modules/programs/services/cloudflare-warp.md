# Cloudflare One client (WARP)

The Zero Trust client for the WiseTech corp network. `cloudflare-warp.nix`
turns on `services.cloudflare-warp`, which runs `warp-svc` as root, opens UDP
2408 and puts `warp-cli` on `PATH`. The package is unfree; `allowUnfree` is
already set repo-wide in `system/nix/nix.nix`.

## Enrolling

Registration is per-device and survives rebuilds — it lives in
`/var/lib/cloudflare-warp`, not in the config:

```bash
warp-cli --accept-tos registration new <organization>
```

`<organization>` is the Zero Trust team name from the corp dashboard (the
`<team>.cloudflareaccess.com` prefix). That opens a browser for SSO, and the
login redirects to a `com.cloudflare.warp://` URL — the package's
`com.cloudflare.warp.desktop` claims that scheme handler and hands the token
back to `warp-cli`, so the browser has to be on this machine. Then:

```bash
warp-cli connect
warp-cli status
warp-cli registration show
```

## Why the tray needs the packaged unit

The taskbar is a Flutter app that loads its assets from the FHS path
`/usr/lib/warp/data`, and nothing in the wrapper fixes that up. The only thing
that makes it work is the `BindReadOnlyPaths=$out:/usr:` that nixpkgs appends
to the unit it ships, so `warp-taskbar` is started from **that** unit rather
than from `hypr/autostart.lua` or a hand-written one — run the binary directly
and it dies on its missing assets. D-Bus activation also names
`warp-taskbar.service` by that exact name (`share/dbus-1/services`).

`systemd.packages` is what links it. Two consequences:

- It links the package's `warp-svc.service` too, which is a second copy of the
  daemon `services.cloudflare-warp` already runs as `cloudflare-warp.service`.
  Both would fight over the same socket, so `warp-svc` is masked
  (`systemd.services.warp-svc.enable = false`).
- `systemd.packages` links a unit but does **not** act on its `[Install]`
  section, so the tray would sit there never started. The `wantedBy` is added
  back as a drop-in (`overrideStrategy = "asDropin"`), which leaves the
  packaged unit — and its bind mount — as the base.

`graphical-session.target` is reached under uwsm, so the tray comes up with the
session and shows in waybar's tray. Nothing goes in `hypr/autostart.lua`.

## Other VPNs on this machine

Mullvad and Tailscale are on the laptop too, and all three want to own the
default route and `/etc/resolv.conf`. WARP is the one the corp network needs;
disconnect the others before connecting it (`mullvad disconnect`,
`tailscale down`). Tailscale is usually the survivable one — WARP's split
tunnel can be told to exclude the tailnet — but that is an org-side setting,
not something this config can set.

```bash
systemctl status cloudflare-warp          # the daemon
systemctl --user status warp-taskbar      # the tray
warp-diag                                 # support bundle, if IT asks
```
