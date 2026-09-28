# Syncthing

Keeps `~/Documents`, `~/Pictures` and `~/Videos` the same on every device.
[`shared.nix`](shared.nix) is the one list of devices and folders; the
personal devices run syncthing from home-manager ([`home.nix`](home.nix)), and
jia runs the system service ([`programs/server/syncthing.nix`](../../server/syncthing.nix)).

Every device shares every folder with every other device. jia is always on, so
two devices that are never online together still sync through it.

## Sync is not a backup

A delete or an overwrite reaches every device. jia keeps what another device
removed or changed for 90 days (staggered versioning, in each folder's
`.stversions`), and the homelab's restic job backs up `/var/lib/syncthing`, so
older history is in restic.

## Network

Global discovery and relays are off. Devices connect by Tailscale name
(`<host>.tailc7b8fd.ts.net`) or find each other on the LAN, so a device that
isn't on the tailnet only syncs at home. The device IDs in `shared.nix` are
therefore not secret: nothing announces them, and a connection still needs
both sides to list each other.

## Adding a device

A device's ID comes from its key, made on first start. To know it before the
first switch, generate the identity where home-manager will look for it:

```
nix shell nixpkgs#syncthing -c syncthing generate --home ~/.local/state/syncthing   # Linux
nix shell nixpkgs#syncthing -c syncthing generate --home ~/Library/Application\ Support/Syncthing   # Mac
```

Put the printed ID in `shared.nix` under the device's `networking.hostName`,
and rebuild every device. A device without an ID is `null` there and left out
of every config.

The phone isn't managed here: add its ID to `shared.nix`, then add jia (and
the folders) by hand in the app.

## GUI

`http://127.0.0.1:8384` on each device. jia's is reached over SSH:
`ssh -L 8384:127.0.0.1:8384 jia`. Changes made there to devices or folders are
reverted on the next switch; `shared.nix` is the source.
