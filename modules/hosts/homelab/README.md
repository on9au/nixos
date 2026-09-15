# jia-opena0 (homelab)

A lid-closed Asus Zenbook UX433FN running Docker containers declared in Nix,
behind Caddy, on `*.opena0.net`. Reached over Tailscale as `jia-opena0`, or on
the LAN at a static `192.168.1.247`. Headless: no `programs/desktop` imports,
and `users/opena0` rather than `users/djpro`.

This replaces the `homelab` repo (`git.opena0.net/on9au/homelab`), whose history
holds the macOS/Colima and Debian eras and their runbooks.

## Services

| Service | URL | Module | Notes |
| --- | --- | --- | --- |
| forgejo | `git.opena0.net` | [`forgejo.nix`](../../programs/server/forgejo.nix) | git; also SSH on 2222 |
| forgejo-runner | none | [`forgejo-runner.nix`](../../programs/server/forgejo-runner.nix) | Actions runner, jobs as sibling containers |
| kanidm | `idm.opena0.net` | [`kanidm.nix`](../../programs/server/kanidm.nix) | identity; OIDC provider for tuwunel |
| tuwunel | `matrix.opena0.net` | [`tuwunel/`](../../programs/server/tuwunel) | Matrix homeserver, `server_name = opena0.net` |
| cinny | `chat.opena0.net` | [`cinny/`](../../programs/server/cinny) | Matrix web client |
| bridges | `<bridge>-media.opena0.net` | [`bridges/`](../../programs/server/bridges) | six mautrix bridges, see below |
| uptime-kuma | `status.opena0.net` | [`uptime-kuma/`](../../programs/server/uptime-kuma) | monitoring, alerts to Discord |
| beszel | `metrics.opena0.net` | [`beszel.nix`](../../programs/server/beszel.nix) | resource metrics; the agent runs on the host |
| diun | none | [`diun.nix`](../../programs/server/diun.nix) | image-update notifications |
| terraria | port 7777 | [`terraria.nix`](../../programs/server/terraria.nix) | tshock; not behind Caddy |
| whoami | `whoami.jia.opena0.net` | [`whoami.nix`](../../programs/server/whoami.nix) | reachability canary |
| backup, liveness | none | [`backup/`](../../programs/server/backup), [`liveness.nix`](../../programs/server/liveness.nix) | systemd timers |

## How it runs

Each service is a `virtualisation.oci-containers` container, which NixOS turns
into a systemd unit named `docker-<name>.service`, logging to journald:

```
systemctl status docker-tuwunel
sudo systemctl restart docker-tuwunel
journalctl -u docker-tuwunel -f
```

**Stop and restart through systemctl, never `docker stop`.** The units restart
on failure and run with `--rm`, so a container stopped behind systemd's back
either comes straight back or disappears — `backup.sh` stops them the same way.

Containers that Caddy routes to join the `proxy` network, created by
`docker-network-proxy.service` with the bridge named `br-proxy`. Routing is by
label, not a Caddyfile — caddy-docker-proxy watches the docker socket:

```nix
labels = {
  caddy = "sub.opena0.net";
  "caddy.reverse_proxy" = "{{upstreams 8080}}";
};
```

Caddy itself is built by Nix (`caddy.withPlugins` with caddy-docker-proxy and
the Cloudflare DNS module) and loaded as an image through `imageStream`.
Changing a plugin version needs a new `hash`: set it to `lib.fakeHash`, build,
and copy the `got:` line.

Certificates come from Let's Encrypt over the Cloudflare DNS-01 challenge.
Public DNS is separate: add a CNAME to `jia.opena0.net` in Cloudflare, or the
name resolves nowhere. `.well-known/matrix/{client,server}` is served by a
**Cloudflare Worker on `opena0.net`**, not by this box — Matrix delegation can
break without anything here changing, hence the Kuma monitor on it.

### Why containers, not NixOS service modules

Moving over was meant to change the host, not the services. Several couldn't
move to nixpkgs anyway: kanidm runs 1.11 and nixpkgs stops at 1.9 (kanidm
refuses a downgrade), nixpkgs' `mautrix-telegram` is the old Python bridge
rather than the Go one running here, and gmessages has no module. forgejo,
beszel, uptime-kuma and cinny do line up, and can go native one at a time.

### State

| Where | What |
| --- | --- |
| docker volumes | `forgejo_data`, `kanidm_data`, `kanidm_certs`, `tuwunel_db`, `uptime-kuma_data`, `beszel_data`; unbacked `caddy_caddy_data`, `caddy_caddy_config`, `diun_data` |
| `/var/lib/homelab/bridges/<bridge>/data` | each bridge's config, registration and SQLite |
| `/var/lib/homelab/tuwunel/appservices` | appservice registrations |
| `/var/lib/homelab/terraria/{config,worlds}` | tshock config and worlds |
| `/var/lib/homelab/forgejo-runner/data` | runner registration and `config.yml` |

The volume names and the `/var/lib/homelab` layout are the old compose
projects' names and tree, so a restore from the existing restic series lands
without renaming anything.

**Nothing starts until `/var/lib/homelab/.restored` exists** — every container
unit and the backup carry `ConditionPathExists` on it (`programs/server/docker.nix`).
A tuwunel that boots on an empty volume mints a new federation signing key, and
a backup of an empty box would snapshot nothing into the series the restore
needs.

### Updates

Every image is pinned in its module except tuwunel, cinny, terraria and whoami,
which track `:latest`. `pull` defaults to `missing`, so `:latest` only moves on
`sudo docker pull <image>` followed by a unit restart. Diun checks every running
image daily at 08:00 and notifies Discord; it never updates anything.

There is no `unattended-upgrades` equivalent: `nix flake update`, then
`nh os switch`.

## Install: reinstalling from Debian

The Debian box is replaced in place. Downtime is the install plus a restore.

### Before wiping Debian

1. **Put the secrets in sops.** Read the current values off the box and enter
   them with `sops modules/hosts/homelab/secrets.yaml` (keys under
   [Secrets](#secrets)):

   ```
   ssh jia 'cd ~/homelab && cat caddy/.env diun/.env forgejo-runner/.env \
     backup/backup.env liveness/liveness.env uptime-kuma/.admin.env \
     && grep -E "^(registration_token|client_secret)" tuwunel/tuwunel.toml'
   ```

   Commit and push: the install clones from GitHub.

2. **Check `tuwunel.toml` against the repo copy.** The repo's
   [`tuwunel.toml`](../../programs/server/tuwunel/tuwunel.toml) was rebuilt from
   the example plus the fixes in the old README, so diff it against the live file:

   ```
   ssh jia "grep -v '^[[:space:]]*#' ~/homelab/tuwunel/tuwunel.toml | grep . \
     | grep -v -e registration_token -e client_secret"
   ```

3. **Verify the restic password** from Bitwarden: `ssh jia ~/homelab/backup/backup.sh check`.
   Losing it makes every snapshot unreadable — the one unrecoverable failure.

4. **Copy the SSH host key off.** `.sops.yaml` already lists this key as the
   host's recipient, so carrying it over means secrets decrypt on first boot,
   and nothing's `known_hosts` changes:

   ```
   ssh -t jia 'sudo tar -C /etc/ssh -czf ~/hostkey.tgz ssh_host_ed25519_key ssh_host_ed25519_key.pub && sudo chown opena0 ~/hostkey.tgz'
   scp jia:hostkey.tgz . && ssh jia rm hostkey.tgz
   ```

   It's a private key: keep it off anything synced, and delete it after the install.

5. **Take the final backup and freeze the box**, so nothing is written after
   the snapshot:

   ```
   ssh -t jia '~/homelab/backup/backup.sh && sudo systemctl disable --now docker.socket docker.service'
   ```

6. **Delete the `jia-opena0` node** in the Tailscale admin console. Otherwise
   the new install joins as `jia-opena0-1` and the `jia` block in
   [`programs/tools/ssh`](../../programs/tools/ssh/home.nix) points at nothing.

### Install

NixOS installer on USB, keyboard attached, the ethernet adapter plugged in.
ext4 on the whole disk, **no LUKS**: after a long power cut nobody is there to
type a passphrase into a closed laptop. The battery rides out short outages;
a long one needs someone to press power, same as before.

```
sudo -i
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart root ext4 1GiB 100%
mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mkfs.ext4 -L nixos /dev/nvme0n1p2
mount /dev/disk/by-label/nixos /mnt
mount --mkdir -o umask=077 /dev/disk/by-label/boot /mnt/boot

nix-shell -p git
git clone https://github.com/on9au/nixos /mnt/home/opena0/nixos
nixos-generate-config --root /mnt --show-hardware-config \
  > /mnt/home/opena0/nixos/modules/hosts/homelab/hardware.nix
git -C /mnt/home/opena0/nixos add modules/hosts/homelab/hardware.nix
```

The `jia-opena0` flake output doesn't exist until `hardware.nix` is added —
the same `builtins.pathExists` guard the laptop uses.

Set a password for the installer's `nixos` user (`passwd nixos`), copy the host
key across from the desktop (`scp hostkey.tgz nixos@<installer-ip>:`), then:

```
mkdir -p /mnt/etc/ssh
tar -C /mnt/etc/ssh -xzf /home/nixos/hostkey.tgz
chmod 600 /mnt/etc/ssh/ssh_host_ed25519_key
nixos-install --flake /mnt/home/opena0/nixos#jia-opena0 --no-root-passwd
nixos-enter --root /mnt -c 'passwd opena0 && chown -R opena0:users /home/opena0/nixos'
reboot
```

`passwd opena0` is the sudo password. SSH never asks for it — key auth only —
but nothing on this box works without sudo.

The checkout has to stay at `/home/opena0/nixos`: `dotfiles.link` resolves
against `$HOME/nixos`, and the live-linked nvim and tmux config dangle without it.

### First boot and restore

```
sudo tailscale up --hostname=jia-opena0
sudo ls /run/secrets    # populated: the carried-over host key decrypted them
```

Nothing else is running yet. Restore the volumes and the data directories from
the last Debian snapshot:

```
sudo docker run --rm --env-file /run/secrets/rendered/restic.env \
  -v forgejo_data:/data/forgejo_data \
  -v kanidm_data:/data/kanidm_data \
  -v kanidm_certs:/data/kanidm_certs \
  -v tuwunel_db:/data/tuwunel_db \
  -v uptime-kuma_data:/data/uptime-kuma_data \
  -v beszel_data:/data/beszel_data \
  -v /var/lib/homelab:/data/homelab \
  restic/restic restore latest --host jia --target / \
    --include /data/forgejo_data --include /data/kanidm_data \
    --include /data/kanidm_certs --include /data/tuwunel_db \
    --include /data/uptime-kuma_data --include /data/beszel_data \
    --include /data/homelab/bridges \
    --include /data/homelab/forgejo-runner/data \
    --include /data/homelab/terraria \
    --include /data/homelab/tuwunel/appservices
sudo touch /var/lib/homelab/.restored
sudo reboot
```

Only the data directories come back; the old tree's compose files, scripts and
`.env` secrets stay in the snapshot. `tuwunel_db` carries the **federation
signing key** and `forgejo_data` forgejo's **SSH host key**, which is why this
is a restore and not a fresh install. The bridges' SQLite comes with
`bridges/`, so their logins survive and nothing needs re-pairing.

### After

- `curl -sS https://whoami.jia.opena0.net` — the canary.
- `sudo systemctl restart docker-uptime-kuma`: every container IP changed at
  once, and Kuma holds stale ones (see Gotchas).
- The bridges start alongside tuwunel and crash-loop until it answers; the units
  restart them. `systemctl list-units 'docker-*'` should settle on all running.
- Federation tester against `matrix.opena0.net`.
- `sudo systemctl start homelab-backup`, then `journalctl -u homelab-backup` —
  and healthchecks.io should see the heartbeat within 5 minutes.
- Commit `hardware.nix` and push.
- Delete `hostkey.tgz` from the desktop.

Rolling back means reinstalling Debian and following the old repo's
`MIGRATION.md` restore phases.

## Secrets

sops-nix, with this host's file at [`secrets.yaml`](secrets.yaml). It is
encrypted to both YubiKeys ([which ones](../../programs/services/ssh-agent/README.md#age-identities-for-sops))
and to this host's SSH key; edit it from the repo root with a YubiKey plugged in:

```
sops modules/hosts/homelab/secrets.yaml
```

| Key | Used by |
| --- | --- |
| `backup/restic_repository`, `backup/restic_password` | restic; the password also lives in Bitwarden |
| `backup/aws_access_key_id`, `backup/aws_secret_access_key` | R2 |
| `backup/healthcheck_url` | backup check on healthchecks.io |
| `caddy/cloudflare_api_token` | ACME DNS-01 (DNS:Edit) |
| `caddy/acme_email` | Let's Encrypt account |
| `diun/discord_webhook` | Diun notifications |
| `forgejo-runner/token` | runner registration; only read while `data/.runner` is missing |
| `liveness/url` | heartbeat check on healthchecks.io |
| `tuwunel/registration_token`, `tuwunel/oidc_client_secret` | substituted into `tuwunel.toml` |
| `uptime-kuma/username`, `uptime-kuma/password` | `setup-monitors.sh` only |

Every key has to exist before the host builds: sops-nix checks the file against
what the modules declare.

Secrets reach a service through `config.sops.secrets.<name>.path` or a
`sops.templates` file — an `--env-file`, or `tuwunel.toml` with placeholders
filled in. Never the value as a Nix string: the store is world-readable and the
repo is public. Templates that a container reads at start carry
`restartUnits`, so editing a secret restarts what uses it.

The host key in `.sops.yaml` is Debian's, carried over by the install. A
reinstall that doesn't keep `/etc/ssh` makes a new key: get its recipient with
`ssh-keyscan -p 7456 -t ed25519 jia-opena0 | ssh-to-age`, replace the
`jia-opena0` entry, run `sops updatekeys modules/hosts/homelab/secrets.yaml`,
and commit.

## Matrix bridges

Six mautrix bridges. They talk to tuwunel over the `proxy` network by container
name; only direct media gives them a public name.

| Bridge | Image | Port | Namespace |
|---|---|---|---|
| telegram | `mautrix/telegram:v26.07` | 29317 | `@telegram_*` |
| whatsapp | `mautrix/whatsapp:v26.07` | 29318 | `@whatsapp_*` |
| discord | `mautrix/discord:v0.7.6` | 29334 | `@discord_*` |
| gmessages | `mautrix/gmessages:v26.05` | 29336 | `@gmessages_*` |
| messenger | `mautrix/meta:v26.07` | 29321 | `@messenger_*` |
| instagram | `mautrix/meta:ig-v26.07` | 29322 | `@instagram_*` |

Instagram split out of mautrix-meta in July 2026 into its own bridge, published
under `ig-` prefixed tags in the same repo. Messenger and Instagram therefore
run as two containers and must not share a user namespace — hence the explicit
`username_template` on each.

The containers are declared in `bridges/default.nix`; their configs are written
by [`bridges/scaffold.sh`](../../programs/server/bridges/scaffold.sh) (as root),
which is re-runnable: existing configs and registrations are patched in place,
never regenerated, so tokens tuwunel already knows stay valid. A new image tag
goes in both files.

### Registration

tuwunel loads appservice registrations from a directory — `appservice_dir =
"/appservices"`, mounted from `/var/lib/homelab/tuwunel/appservices`. Drop a
registration YAML in and restart `docker-tuwunel`. No pasting into `#admins`.

Verify a registration took without a Matrix client:

```
tok=$(sudo awk '/^as_token:/{gsub(/"/,"");print $2}' /var/lib/homelab/tuwunel/appservices/whatsapp.yaml)
curl -H "Authorization: Bearer $tok" https://matrix.opena0.net/_matrix/client/v3/account/whoami
```

A 200 with the appservice's sender_localpart means tuwunel knows it.

### Double puppeting

`appservices/doublepuppet.yaml` is a registration that claims the whole local
user namespace **non-exclusively** (`@.*:opena0.net`, `exclusive: false` —
exclusive would lock out real users and every other appservice). Every bridge
gets that same token as its double-puppet secret, so your own messages appear
as you rather than as a bot.

The config key differs by bridge generation: bridgev2 bridges use
`double_puppet.secrets`, while discord 0.7.6 predates that and uses
`bridge.login_shared_secret_map`. `double_puppet.servers` must **not** contain
your own server — only the secret is needed for the local domain.

### Direct media

Enabled on every bridge except Google Messages. Instead of reuploading each
attachment into tuwunel's media repo, the bridge mints signed `mxc://` URIs on
`<bridge>-media.opena0.net` and serves the bytes itself.

Each of those names needs a CNAME to `jia.opena0.net`, and the whole subdomain
is proxied to the bridge — `/_matrix/federation`, `/_matrix/client/v1/media`,
`/_matrix/key` and `.well-known` all have to land on it. Port 443 is enough;
the bridge serves its own 8448 → 443 redirect.

**Google Messages cannot do this.** RCS media has no HTTP URL to hand out, and
the connector refuses to start rather than ignoring the setting: `direct media
is enabled in config, but the network connector does not support it`.

`direct_media.server_key` signs the `mxc://` URIs. It is generated on first
start and lives in each bridge's `config.yaml` — regenerating it invalidates
every media link already sent.

### Google Messages: duplicate sends

Google Messages allows exactly one active web session. If a
`messages.google.com/web` tab is open anywhere — including the private window
used during login — it takes the active-device slot from the bridge. Messages
arrive fine for the recipient but appear twice in Matrix, and the bot warns
"phone has not confirmed message delivery".

The bridge tags each outgoing message with a `tmp_id` and waits for the phone
to echo it back. When another session owns the slot the echo comes back with
`tmp_id` empty, so the bridge cannot match its own message and posts a second
copy. `network.aggressive_reconnect = true` makes the bridge reclaim the slot;
close stray browser sessions as well.

### Logging in

Each bridge starts `UNCONFIGURED` — normal, and means no account is linked.
Start a DM with the bot and send `login`: `@telegrambot` `@whatsappbot`
`@discordbot` `@gmessagesbot` `@messengerbot` `@instagrambot`, all
`:opena0.net`. WhatsApp and Google Messages pair by QR, Telegram by phone
number, Discord by token, Messenger and Instagram by cookies.

## Backups

restic → Cloudflare R2, nightly at 04:00 (`Persistent`, so a run missed while
the box was down fires on boot), reporting to healthchecks.io. Retention 7
daily / 4 weekly / 6 monthly.

Backed up: the six stateful volumes and `/var/lib/homelab`. restic runs in a
container so the paths inside the repository — `/data/<volume>`,
`/data/homelab` — are the ones the macOS and Debian hosts wrote, and the series
and its retention carry straight on. The stateful containers are stopped for
the snapshot (~30 s); RocksDB and SQLite both tear if copied live.

```
sudo modules/programs/server/backup/backup.sh              # run now
sudo modules/programs/server/backup/backup.sh snapshots    # any restic command passes through
sudo modules/programs/server/backup/backup.sh check
```

Restoring a single service: stop its unit, restore into its volume with the
`docker run … restic/restic restore` shape from the install above, start it.

## Monitoring

| Layer | Watcher | Catches |
|---|---|---|
| services | Uptime Kuma → Discord | a service down while the box is up |
| backups | healthchecks.io | backup failed or never ran |
| the box | healthchecks.io (5 min heartbeat) | jia dark, or the network gone |
| resources | Beszel | usage over time |

Kuma cannot report that jia is down — it dies with it; that is what the
heartbeat is for. Monitors are declared in
[`uptime-kuma/setup-monitors.py`](../../programs/server/uptime-kuma/setup-monitors.py);
`sudo ./setup-monitors.sh` edits by name rather than duplicating.

Beszel's agent is `services.beszel.agent` on the host, not a container, so it
sees the battery, temperatures and the physical disk, and container stats
through the docker socket. The hub connects *to* it on
`host.docker.internal:45876`; that arrives on `br-proxy`, the only interface
the firewall opens the port on.

## Forgejo Actions runner

Registered against this same forgejo, running jobs as sibling containers.

- It joins the docker group by GID. NixOS fixes that GID (131), where Colima
  and Debian each picked their own.
- `container.network: proxy` in `data/config.yml` — job containers otherwise
  get a per-workflow network where `forgejo` does not resolve, so
  `actions/checkout` cannot clone. This does put CI jobs on the same network as
  every service.

A fresh registration token, only needed if `data/.runner` is lost:

```
sudo docker exec -u git forgejo forgejo forgejo-cli actions generate-runner-token
```

(as `git`, not root — forgejo refuses to run as root.) Put it in sops as
`forgejo-runner/token`.

## A laptop as a server

[`hardware/power/always-on.nix`](../../hardware/power/always-on.nix) ignores the
lid and masks every sleep target; the lid is shut, so nothing else keeps it
awake. [`devices/zenbook-ux433fn.nix`](../../devices/zenbook-ux433fn.nix):

- **Battery capped at 60%.** It lives on AC, and the battery is the only UPS.
  A battery above the cap reads `Not charging` and drifts down to it; that is
  the feature working. The cap can reset when the adapter is replugged, which
  the oneshot does not catch — `cat /sys/class/power_supply/BAT0/charge_control_end_threshold`
  after moving power around.
- **The MX150 is powered down.** Blacklisting nouveau alone leaves the card
  unbound and `active`; the udev rule sets `power/control=auto`. Check with
  `cat /sys/bus/pci/devices/0000:02:00.0/power/runtime_status` — `suspended`.
- **No TLP.** `power/laptop.nix` is not imported: a power-saving daemon fights
  a server on permanent AC over the ethernet adapter's wake behaviour.

The USB ethernet adapter gets a MAC-derived name (`enx…`), so the `30-lan`
network matches on `Type = ether` rather than a name.

## SSH, and the lockout guard

`services.openssh.ports = [7456]`, matching the `Port 7456` already in the ssh
client config. `openFirewall` defaults on, so the port opens itself.

`programs/services/sshd.nix` turns off password auth, which makes an empty
`authorizedKeys` list a locked door on a headless machine. It therefore
asserts the list is non-empty, so a missing key fails the build:

```
Failed assertions:
- programs/services/sshd.nix: opena0 has no authorizedKeys and password auth
  is disabled -- this switch would lock you out.
```

Both YubiKeys' resident keys are in [`users/opena0`](../../users/opena0/default.nix),
shared with the proxy, so the assertion passes; it stays to catch the list being
emptied by mistake.

## Gotchas

- **tuwunel caches DNS for 3 hours** (`dns_min_ttl = 10800`), so a recreated
  bridge container would keep receiving transactions at its old IP and report
  `Homeserver -> appservice connection is not working`.
  `dns_passthru_appservices = true` resolves appservices through the system
  resolver instead.
- **Uptime Kuma holds stale container IPs** after a recreate, reporting
  `ECONNREFUSED <old-ip>` for a service that is demonstrably healthy. Kuma's
  own `dnsCache` is already off, so this is Node's connection reuse;
  `sudo systemctl restart docker-uptime-kuma` clears it. Recreating several
  containers at once can make them swap IPs, so two monitors can fail pointing
  at each other's address.
- **mautrix `username_template` lives under `appservice:`, not `bridge:`.**
  Setting it in the wrong place silently does nothing and the namespace comes
  out wrong.
- **`oauth_aware_preferred` / `oidc_aware_preferred` are not tuwunel options.**
  Both spellings log as unknown and are ignored.
- **uptime-kuma-api is older than the hub**: `monitor.conditions` is NOT NULL in
  the schema but the library neither sends nor accepts it, so *creating* a
  monitor fails with a raw SQLITE_CONSTRAINT error while editing one works.
  `setup-monitors.py` patches the payload builder.
- **`terraria` is not on the `proxy` network**, so Kuma checks it via
  `host.docker.internal:7777` rather than by container name.
- **`docker attach terraria` can't send console commands.** Compose's
  `stdin_open` has no systemd equivalent: `-i` makes docker demand a terminal
  the unit doesn't have, so the container gets `--tty` alone.
- **forgejo bind-mounts `/etc/timezone`**, which NixOS doesn't have and docker
  would replace with an empty directory; `forgejo.nix` writes one.

## Not imported, deliberately

`filesystems/btrfs.nix` schedules a scrub of `/` and would fail on ext4.

`system/network.nix` is NetworkManager; this host takes
[`network-server.nix`](../../system/network-server.nix) — systemd-networkd plus
resolved, since there is no user session to hand link management to — with the
static `30-lan` network overriding its DHCP.
