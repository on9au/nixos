# Anime

Seanime keeps the AniList list and picks releases from nyaa, qBittorrent
downloads them into `/srv/anime`, and Jellyfin plays them to the phone and
anything else on the tailnet.

| Container | Tailnet URL | Does |
| --- | --- | --- |
| gluetun | none | Mullvad WireGuard; the only network qBittorrent and Seanime have |
| qbittorrent | `http://jia-opena0:8080` | downloads |
| seanime | `http://jia-opena0:43211` | AniList, nyaa search, auto-downloader |
| jellyfin | `http://jia-opena0:8096` | library and playback; reads `/srv/anime` read-only |

## Network

- **Tailnet only.** Containers publish on `127.0.0.1`, and
  `anime-tailscale-serve.service` serves those ports on jia's tailnet address
  over plain HTTP, inside WireGuard. Nothing goes through Caddy or the proxy
  VPS, so streams don't count against its transfer, and phone↔jia is a
  direct Tailscale connection when it can be.
- **Torrents leave from the home IP, inside Mullvad.** gluetun sits alone on
  the docker `vpn` network (`10.200.0.0/24`, bridge `br-vpn`), which a routing
  rule in [`hosts/homelab`](../../../hosts/homelab/default.nix) sends past the
  exit node. The VPS never carries the traffic; the ISP sees WireGuard to
  Mullvad.
- **Fails closed, twice.** qBittorrent and Seanime share gluetun's network
  namespace, and gluetun's firewall drops everything that isn't the tunnel.
  Behind that, a host rule in `gluetun.nix` drops anything leaving `br-vpn`
  that isn't UDP to port 51820, so not even a broken gluetun can send
  cleartext from the home IP. Seanime's nyaa and AniList requests go through
  Mullvad too, which also gets past ISP blocks on nyaa.
- **No port forwarding** (Mullvad dropped it), so peers can't connect in.
  Downloads of anything well-seeded are fine; seeding is mostly to peers that
  connect out.
- **Restart gluetun with the other two**: `sudo systemctl restart
  docker-gluetun` takes qBittorrent and Seanime with it. If gluetun's
  container is recreated alone, they're left in the old namespace with no
  network.

## Access

- **Every app has its own login**, because the tailnet includes the proxy
  VPS, which faces the internet. Seanime's password comes from sops (it
  otherwise trusts any private or Tailscale address with everything). Jellyfin
  and qBittorrent set theirs on first start, so do that straight after the
  switch: until then Jellyfin's setup wizard belongs to whoever opens it first.
- **qBittorrent skips authentication for localhost**, which is only gluetun
  and Seanime. Tailnet requests arrive through docker's proxy from the
  `br-vpn` gateway, so they still need the password.
- **A Tailscale ACL** limiting ports 8080, 8096 and 43211 on `jia-opena0` to
  your own devices would keep the VPS out entirely. That's in the admin
  console, not this repo.
- **The containers** run as `media` with no capabilities, except gluetun:
  root with `NET_ADMIN`, `NET_BIND_SERVICE` and `NET_RAW`, confined to its own
  network namespace. Jellyfin reads the library read-only. Jellyfin is on
  docker's default bridge with an ordinary route out, like the other
  containers; a release crafted to exploit ffmpeg would land there, as
  `media`.

## State

`/srv/anime` is the library, and `/var/lib/media/{qbittorrent,seanime,jellyfin}`
the apps' state. None of it is backed up: it's outside `/var/lib/homelab`. AniList
keeps watch progress, so a lost Seanime is a re-link, and a lost Jellyfin is a
rescan. Everything runs as `media` (2000).

The internal disk is 512 GB with everything else on it. Delete watched
episodes, or move `/srv/anime` to an external drive (a `fileSystems` entry
mounted there, chowned to `media`).

## Secrets

| Key | Used by |
| --- | --- |
| `gluetun/wireguard_private_key` | Mullvad device key, `PrivateKey` in the WireGuard config |
| `gluetun/wireguard_addresses` | that device's tunnel address, `Address` in the same file (IPv4 only, e.g. `10.66.1.2/32`) |
| `seanime/password` | Seanime's login; `openssl rand -base64 24`. Seanime also writes it into `/var/lib/media/seanime/config.toml` |

From mullvad.net → *WireGuard configuration* → *Generate key*, then download
any Linux config and copy the two values. It uses one of the account's five
devices.

## First start

1. **Jellyfin** at `:8096`, first: make the admin account, add a *Shows*
   library on `/anime`, and under *Dashboard → Playback → Transcoding* pick
   Intel QSV with `/dev/dri/renderD128`. On Android, Findroid plays through
   mpv, so fansub ASS subtitles direct-play instead of being burned in by a
   transcode.
2. **qBittorrent** at `:8080`. The temporary admin password is in
   `journalctl -u docker-qbittorrent`. Under *Options*:
   - *WebUI*: set a real password, and tick *Bypass authentication for clients
     on localhost* (see [Access](#access)).
   - *Downloads*: default save path `/anime`, temp folder off, and *Excluded
     file names* `*.exe`, `*.scr`, `*.bat`, `*.cmd`, `*.lnk`, `*.msi`, `*.vbs`
     — fake releases carry those, and nothing here needs them.
   - *BitTorrent*: a share ratio limit (2, then *Stop torrent*) so it doesn't
     seed forever.
3. **Seanime** at `:43211`, with the `seanime/password` password. Log in to
   AniList, set the library to `/anime`, and set the torrent client to
   qBittorrent at `127.0.0.1:8080` with no credentials. The auto-downloader
   (*Auto Downloader* → rules per show) watches the currently airing shows on
   the list. Install extensions only from sources you trust: they run code
   inside Seanime.
