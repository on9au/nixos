# Syncthing

Keeps `~/Documents`, `~/Pictures` and `~/Videos` (`~/Movies` on the Mac) the
same on every computer, and carries the phone's backups to jia.
[`shared.nix`](shared.nix) is the one list of devices and folders; the
personal devices run syncthing from home-manager ([`home.nix`](home.nix)), and
jia runs the system service ([`programs/server/syncthing.nix`](../../server/syncthing.nix)).

| Folder | Devices |
| --- | --- |
| `documents`, `pictures`, `videos` | every computer |
| `phone-backup` | the phone and jia; receive-only on jia |

jia is in every folder and always on, so two devices that are never online
together still sync through it.

`Photos Library.photoslibrary` and `.DS_Store` are ignored everywhere: Apple
Photos keeps its library, a database, in `~/Pictures`.
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

The phone (Syncthing-Fork, keyed by its Tailscale name) isn't managed here:
add its ID to `shared.nix`, switch jia, then accept jia and the
`phone-backup` folder in the app. Its global discovery and relays have to be
turned off by hand, and the app set to *Unrestricted* battery use, or
OxygenOS stops it in the background.

A new folder goes in `shared.nix` with its `devices`; a computer only gets
the folders that list it.

## GUI

`http://127.0.0.1:8384` on each device. jia's is reached over SSH:
`ssh -L 8384:127.0.0.1:8384 jia`. Changes made there to devices or folders are
reverted on the next switch; `shared.nix` is the source.
