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
| forgejo | `git.opena0.net` | [`forgejo.nix`](../../programs/server/forgejo.nix) | git; SSH on 2222, public as `jia.opena0.net:22` |
| forgejo-runner | none | [`forgejo-runner.nix`](../../programs/server/forgejo-runner.nix) | Actions runner, jobs on its own rootless docker daemon |
| socket-proxy | none | [`socket-proxy.nix`](../../programs/server/socket-proxy.nix) | read-only docker API for caddy and diun |
| kanidm | `idm.opena0.net` | [`kanidm.nix`](../../programs/server/kanidm.nix) | identity; OIDC provider for tuwunel, forgejo, open-webui, beszel and actual. See [Kanidm](#kanidm) |
| tuwunel | `matrix.opena0.net` | [`tuwunel/`](../../programs/server/tuwunel) | Matrix homeserver, `server_name = opena0.net` |
| cinny | `chat.opena0.net` | [`cinny/`](../../programs/server/cinny) | Matrix web client |
| open-webui | `ai.opena0.net` | [`open-webui.nix`](../../programs/server/open-webui.nix) | chat client for the DeepSeek API; Kanidm login only |
| actual | `budget.opena0.net` | [`actual.nix`](../../programs/server/actual.nix) | Actual Budget sync server; Kanidm login only. See [Actual Budget](#actual-budget) |
| actual-ai | none | [`actual-ai/`](../../programs/server/actual-ai) | categorizes Actual transactions with DeepSeek; run by hand, see [Categorizing with actual-ai](#categorizing-with-actual-ai) |
| bridges | `<bridge>-media.opena0.net` | [`bridges/`](../../programs/server/bridges) | six mautrix bridges, see below |
| uptime-kuma | `status.opena0.net` | [`uptime-kuma/`](../../programs/server/uptime-kuma) | monitoring, alerts to Discord |
| beszel | `metrics.opena0.net` | [`beszel.nix`](../../programs/server/beszel.nix) | resource metrics; the agent runs on the host. Kanidm login, set up in PocketBase (see [Kanidm](#kanidm)) |
| diun | none | [`diun.nix`](../../programs/server/diun.nix) | image-update notifications |
| terraria | port 7777 | [`terraria.nix`](../../programs/server/terraria.nix) | tshock; not behind Caddy |
| whoami | `whoami.jia.opena0.net` | [`whoami.nix`](../../programs/server/whoami.nix) | reachability canary |
| syncthing | none | [`syncthing.nix`](../../programs/server/syncthing.nix) | the always-on member of every folder; see [its README](../../programs/services/syncthing/README.md) |
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
label, not a Caddyfile — caddy-docker-proxy watches the docker API:

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
Public traffic arrives through the [proxy VPS](../proxy/README.md#the-proxy-itself),
and a new name needs a CNAME to `jia.opena0.net` in Cloudflare, or it resolves
nowhere ([Public DNS](../proxy/README.md#public-dns-and-cloudflare)).
`.well-known/matrix/{client,server}` is served by a
**Cloudflare Worker on `opena0.net`**, not by this box — Matrix delegation can
break without anything here changing, hence the Kuma monitor on it.

### Hardening

- **Nothing but the socket proxy mounts the docker socket.** Caddy and Diun
  read the API through `socket-proxy`, which passes GETs for containers,
  images, networks and info only. It sits on the `socket` network (internal,
  joined by those three), because inspecting a container returns its
  environment — secrets included.
- **Containers start with no capabilities** and `no-new-privileges`
  (`docker.nix`). An image whose entrypoint chowns and drops to a user gets
  those capabilities back in its own module; a new service that dies at start
  with `Operation not permitted` needs the same. Root without capabilities
  can't touch another user's files either, so what tuwunel and terraria
  bind-mount from `/var/lib/homelab` is kept root-owned by tmpfiles rules in
  their modules.
- **sshd answers on Tailscale and the LAN only**, and Docker's published ports
  never pass the NixOS firewall at all: 80, 443, 2222 and 7777 are open
  whatever `networking.firewall` says.
- **Outbound traffic leaves through the proxy VPS**, jia's Tailscale
  [exit node](../proxy/README.md#jias-exit-node). It fails closed: with the
  proxy down, jia has no internet, but LAN access stays
  (`--exit-node-allow-lan-access`), so DNS through the router and LAN SSH
  still work.
- **`opena0` is not in the docker group** and is not a nix trusted user; both
  are root without the sudo password. `sudo docker …`.

### Why containers, not NixOS service modules

Moving over was meant to change the host, not the services. Several couldn't
move to nixpkgs anyway: nixpkgs' `mautrix-telegram` is the old Python bridge
rather than the Go one running here, and gmessages has no module. forgejo,
beszel, uptime-kuma and cinny do line up, and can go native one at a time.
Kanidm already has, for declarative provisioning ([Kanidm](#kanidm)).

### State

| Where | What |
| --- | --- |
| docker volumes | `forgejo_data`, `tuwunel_db`, `uptime-kuma_data`, `beszel_data`, `open-webui_data`, `actual_data`; unbacked `caddy_caddy_data`, `caddy_caddy_config`, `diun_data`, `forgejo-runner_dind` |
| `/var/lib/kanidm` | Kanidm's database; `/var/lib/kanidm-tls`, its self-signed certificate, isn't backed up |
| `/var/lib/homelab/bridges/<bridge>/data` | each bridge's config, registration and SQLite |
| `/var/lib/homelab/tuwunel/appservices` | appservice registrations |
| `/var/lib/homelab/terraria/{config,worlds}` | tshock config and worlds |
| `/var/lib/homelab/forgejo-runner/data` | runner registration and `config.yml` |
| `/var/lib/syncthing` | synced folders, their `.stversions`, and syncthing's identity |

The volume names and the `/var/lib/homelab` layout are the old compose
projects' names and tree, so a restore from the existing restic series lands
without renaming anything.

**Nothing starts until `/var/lib/homelab/.restored` exists** — every container
unit, kanidm, syncthing and the backup carry `ConditionPathExists` on it.
A tuwunel that boots on an empty volume mints a new federation signing key, and
a backup of an empty box would snapshot nothing into the series the restore
needs.

### Updates

Every image is pinned to an exact version in its module, so an update is a tag
bump and a switch. Diun checks every running image daily at 08:00 and notifies
Discord; it never updates anything.

There is no `unattended-upgrades` equivalent: `nix flake update`, then
`nh os switch`.

## Reinstall

A reinstall is a fresh NixOS plus a restore from restic. This is how jia came
over from Debian; the Debian-specific steps are in this file's git history.

### Before wiping

1. **Verify the restic password** from Bitwarden:
   `sudo modules/programs/server/backup/backup.sh check`. Losing it makes every
   snapshot unreadable — the one unrecoverable failure.

2. **Copy the SSH host key off**, so secrets decrypt on first boot and
   nothing's `known_hosts` changes
   ([host keys](../../../README.md#secrets)):

   ```
   ssh -t jia 'sudo tar -C /etc/ssh -czf ~/hostkey.tgz ssh_host_ed25519_key ssh_host_ed25519_key.pub && sudo chown opena0 ~/hostkey.tgz'
   scp jia:hostkey.tgz . && ssh jia rm hostkey.tgz
   ```

   It's a private key: keep it off anything synced, and delete it after the install.

3. **Take the final backup and freeze the box**, so nothing is written after
   the snapshot:

   ```
   ssh -t jia 'sudo ~/nixos/modules/programs/server/backup/backup.sh && sudo systemctl disable --now docker.socket docker.service kanidm.service'
   ```

4. **Delete the `jia-opena0` node** in the Tailscale admin console. Otherwise
   the new install joins as `jia-opena0-1` and the `jia` block in
   [`programs/tools/ssh`](../../programs/tools/ssh/home.nix) points at nothing.

### Install

NixOS installer on USB, keyboard attached, the ethernet adapter plugged in.
ext4 on the whole disk, **no LUKS**: after a long power cut nobody is there to
type a passphrase into a closed laptop. The battery rides out short outages;
a long one needs someone to press power.

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

Set a password for the installer's `nixos` user (`passwd nixos`), copy the host
key across from the desktop (`scp hostkey.tgz nixos@<installer-ip>:`), then:

```
mkdir -p /mnt/etc/ssh
tar -C /mnt/etc/ssh -xzf /home/nixos/hostkey.tgz
chmod 600 /mnt/etc/ssh/ssh_host_ed25519_key
nixos-install --flake /mnt/home/opena0/nixos#jia-opena0 --no-root-passwd
nixos-enter --root /mnt -c 'chown -R opena0:users /home/opena0/nixos'
reboot
```

`opena0`'s sudo password is the `opena0/password_hash` secret, set on first
boot once the host key has decrypted it; `users.mutableUsers` is off, so
`passwd` on the box doesn't last. SSH never asks for it — key auth only — but
nothing on this box works without sudo.

### First boot and restore

```
sudo tailscale up --hostname=jia-opena0
sudo systemctl restart tailscaled-set   # --exit-node needs the tailnet to resolve the proxy
sudo ls /run/secrets    # populated: the carried-over host key decrypted them
```

Nothing else is running yet. Restore the volumes and the data directories from
the last snapshot:

```
sudo docker run --rm --env-file /run/secrets/rendered/restic.env \
  -v forgejo_data:/data/forgejo_data \
  -v tuwunel_db:/data/tuwunel_db \
  -v uptime-kuma_data:/data/uptime-kuma_data \
  -v beszel_data:/data/beszel_data \
  -v open-webui_data:/data/open-webui_data \
  -v actual_data:/data/actual_data \
  -v /var/lib/kanidm:/data/kanidm \
  -v /var/lib/syncthing:/data/syncthing \
  -v /var/lib/homelab:/data/homelab \
  restic/restic restore latest --host jia --target / \
    --include /data/forgejo_data --include /data/tuwunel_db \
    --include /data/uptime-kuma_data --include /data/beszel_data \
    --include /data/open-webui_data --include /data/actual_data \
    --include /data/kanidm \
    --include /data/syncthing \
    --include /data/homelab/bridges \
    --include /data/homelab/forgejo-runner/data \
    --include /data/homelab/terraria \
    --include /data/homelab/tuwunel/appservices
sudo touch /var/lib/homelab/.restored
sudo reboot
```

`tuwunel_db` carries the **federation signing key** and `forgejo_data`
forgejo's **SSH host key**, which is why this is a restore and not a fresh
install. The bridges' SQLite comes with `bridges/`, so their logins survive and
nothing needs re-pairing. Kanidm's `domain` in `kanidm.nix` has to match the
restored database: a mismatch makes the first start rename the domain, and
every passkey stops working.

### After

- `curl -sS https://whoami.jia.opena0.net` — the canary.
- `sudo systemctl restart docker-uptime-kuma`: every container IP changed at
  once, and Kuma holds stale ones (see [Gotchas](#gotchas)).
- The bridges start alongside tuwunel and crash-loop until it answers; the units
  restart them. `systemctl list-units 'docker-*'` should settle on all running.
- Federation tester against `matrix.opena0.net`.
- `sudo systemctl start homelab-backup`, then `journalctl -u homelab-backup` —
  and healthchecks.io should see the heartbeat within 5 minutes.
- Commit `hardware.nix` and push.
- Delete `hostkey.tgz` from the desktop.

## Secrets

[`secrets.yaml`](secrets.yaml); the workflow is in the
[top-level README](../../../README.md#secrets).

| Key | Used by |
| --- | --- |
| `actual/oidc_client_secret` | the `actual` client in Kanidm; `openssl rand -hex 32` |
| `backup/restic_repository`, `backup/restic_password` | restic; the password also lives in Bitwarden |
| `backup/aws_access_key_id`, `backup/aws_secret_access_key` | R2 |
| `backup/healthcheck_url` | backup check on healthchecks.io |
| `beszel/oidc_client_secret` | the `beszel` client in Kanidm; also pasted into PocketBase's OIDC provider |
| `caddy/cloudflare_api_token` | ACME DNS-01 (DNS:Edit) |
| `caddy/acme_email` | Let's Encrypt account |
| `diun/discord_webhook` | Diun notifications |
| `forgejo-runner/token` | runner registration; only read while `data/.runner` is missing |
| `kanidm/group_members` | who is in each provisioned group, as a YAML block; see [Kanidm](#kanidm) |
| `kanidm/idm_admin_password` | `idm_admin`, reset to this on every start |
| `liveness/url` | heartbeat check on healthchecks.io |
| `open-webui/deepseek_api_key`, `open-webui/oidc_client_secret` | DeepSeek (also actual-ai's), and the `open-webui` client in Kanidm |
| `open-webui/secret_key` | open-webui session signing; `openssl rand -hex 32` |
| `opena0/password_hash` | `opena0`'s login and sudo password, from `mkpasswd -m yescrypt` |
| `tuwunel/oidc_client_secret` | substituted into `tuwunel.toml`, and the `tuwunel` client in Kanidm |
| `uptime-kuma/username`, `uptime-kuma/password` | `setup-monitors.sh` only |

## Kanidm

Kanidm runs as `services.kanidm` rather than a container, built from nixpkgs'
`kanidmWithSecretProvisioning_1_11`. Those patches let provisioning set OAuth2
client secrets and the `idm_admin` password from sops, which the stock image
can't. On every start, `kanidm-provision` makes Kanidm's groups and OAuth2
clients match what the modules declare under `services.kanidm.provision`.

- **A service declares its own group and client** next to its container;
  [`open-webui.nix`](../../programs/server/open-webui.nix) is the example. The
  client secret is a sops key (owner `kanidm`) that both sides read, so nothing
  is copied out of Kanidm.
- **Members live in `kanidm/group_members`**, deep-merged into the declared
  state, so the public repo doesn't say who has access. In `secrets.yaml` it is
  a block string of YAML, which yq merges into the JSON state:

  ```yaml
  kanidm:
      group_members: |
          groups:
            open-webui_users:
              members: [djpro]
  ```

  Members added by hand to a provisioned group are dropped on the next start.
  Persons can go in the same block (`persons: {<name>: {displayName: …,
  mailAddresses: […]}}`); their credentials can't, so a new person still
  needs `kanidm person credential create-reset-token <name>`.
- **Removing a group or client from Nix deletes it from Kanidm**, but only if
  provisioning created it (tracked in the `ext_idm_provisioned_entities`
  group). Anything made by hand is left alone.
- **Settings a client doesn't declare are reset to their defaults.** The
  tuwunel and forgejo clients were made by hand and are declared to match
  what was live; on tuwunel, a wrong `preferShortUsername` would give every
  Matrix user a new ID. Without `basicSecretFile` a client's secret is left
  alone, which is how forgejo keeps the one stored in its own database.
- **Beszel's side lives in PocketBase**, set once at
  `https://metrics.opena0.net/_/`: turn off "Hide collection create and edit
  controls" in settings, then the `users` collection → Options → OAuth2 →
  OpenID Connect. Client ID `beszel`, the secret from
  `beszel/oidc_client_secret`, auth URL `https://idm.opena0.net/ui/oauth2`,
  token URL `https://idm.opena0.net/oauth2/token`, user info URL
  `https://idm.opena0.net/oauth2/openid/beszel/userinfo`, PKCE on. Turn the
  switch back on afterwards. An existing Beszel user is matched by email, and
  `USER_CREATION` makes accounts for anyone else in `beszel_users`.
- **A client's icon** on Kanidm's apps page is its `imageFile`: either the
  upstream logo through `pkgs.fetchurl`, pinned by hash as `open-webui.nix`
  does, or a file next to the module (`./icon.svg`). It's uploaded again on
  every start.
- **Clients and groups nothing declares are left as they are**: the old
  `matrix` (Synapse) and `nyanet-*` clients, and the unused groups. Delete
  them by hand if they're dead.

Anything else is done by hand on jia: `kanidm login -D idm_admin`, with the
password from `sudo cat /run/secrets/kanidm/idm_admin_password`.

Caddy reaches Kanidm as `host.docker.internal:8443`, which the firewall opens
on `br-proxy` only. caddy-docker-proxy builds sites from container labels, so
the route is a label `kanidm.nix` puts on the caddy container. Between the two
is a self-signed certificate from `kanidm-tls.service`, which Caddy doesn't
verify.

Kanidm upgrades one minor version at a time: 1.11 → 1.12 is a package bump to
`kanidmWithSecretProvisioning_1_12` once nixpkgs has it, after reading the
release notes. Diun doesn't watch it.

## Actual Budget

The sync server from `actualbudget/actual-server`, on the public internet like
everything else here, with Kanidm as its only login. The clients are the
`actual-client` package on the desktop and laptop
([`apps/actual.nix`](../../programs/apps/actual.nix)) and the `actual` cask on
the Mac. The web app at `budget.opena0.net` does the same job anywhere else.

- **The app's own OpenID, not a forward-auth gate in front.** The desktop
  apps sync with a token header, not a browser cookie, so a forward-auth
  redirect would break them. A gate in front would also be a second login
  that guards nothing the app's own login doesn't. Kanidm decides who gets in
  (`actual_users`), and passkeys and MFA live there.
- **OpenID only.** `ACTUAL_ALLOWED_LOGIN_METHODS=openid` and
  `ACTUAL_OPENID_ENFORCE` turn off the password and header logins. Configuring
  OpenID through the environment makes the server set it up on every start,
  before anyone could set a password. If that start-up step fails (Kanidm
  unreachable on the very first boot), the server is left with no login method,
  and its `/account/bootstrap` would accept a password from anyone. Caddy
  answers that path with a 403.
- **The first person to log in becomes the owner** (admin). Others in
  `actual_users` get in only once the owner has made them a user of the same
  name (`ACTUAL_USER_CREATION_MODE=manual`). That name is Kanidm's
  `preferred_username`, short because of `preferShortUsername`: changing that
  gives everyone a new, empty account.
- **Sessions last a day** (`ACTUAL_TOKEN_EXPIRATION`); upstream's default never expires them.
- **Kanidm signs this client's tokens RS256** (`enableLegacyCrypto`), because
  Actual's OpenID library rejects Kanidm's default ES256.
- **Encrypt each budget** (budget menu → *Encryption*). The password never
  leaves the client, so the server, `actual_data` and the restic snapshots
  hold only ciphertext. Losing the password loses the budget's server copy.
- **The container** runs as the image's `actual` user (1001), with a
  read-only root and no capabilities.
- **Bank sync isn't set up.** Setting it up stores the provider's credentials in the
  server's database, readable by anyone who gets its admin, so think about it
  first.

Bringing it up: put `actual/oidc_client_secret` in `secrets.yaml`, add
`actual_users` with you in it to `kanidm/group_members`, add a proxied CNAME
`budget` → `jia.opena0.net` in Cloudflare, switch, and log in once straight
away so the owner is you. Then `sudo ./setup-monitors.sh` adds the Kuma
monitor.

### Categorizing with actual-ai

[actual-ai](https://github.com/sakowicz/actual-ai) sends each uncategorized
transaction (payee, amount, notes, date) and the category list to DeepSeek's
`deepseek-flash`, and sets the category it picks. It never runs on its own:

```
sudo systemctl start docker-actual-ai-dry-run   # logs what it would do, changes nothing
journalctl -u docker-actual-ai-dry-run -f
sudo systemctl start docker-actual-ai           # does it
```

In the app, filter notes for `#actual-ai` to review what it set, and for
`#actual-ai-miss` to see what it couldn't place.

- **No password, no token to paste.** actual-ai only knows password login, so
  [`session-token.cjs`](../../programs/server/actual-ai/session-token.cjs),
  preloaded into it, hands `@actual-app/api` a session token instead. The
  unit makes that session itself, for the owner, straight into
  `account.sqlite`, with a three-hour expiry, and deletes it when it stops.
  The budget's sync ID comes from the same database, so it expects exactly
  one budget.
- **An encrypted budget** has its password asked for on the terminal running
  `systemctl start`, and kept only in `/run` for that run.
- **Dry run has to be listed.** Upstream's README calls it the default, but
  an unlisted feature is off, so `docker-actual-ai` without `dryRun` writes.
- It reaches Actual through `budget.opena0.net` rather than the `proxy`
  network, so the token goes over TLS and nothing else is reachable from it.

## Matrix bridges

Six mautrix bridges. They talk to tuwunel over the `proxy` network by container
name; only direct media gives them a public name.

| Bridge | Image | Port | Namespace |
|---|---|---|---|
| telegram | `mautrix/telegram:v26.09` | 29317 | `@telegram_*` |
| whatsapp | `mautrix/whatsapp:v26.09` | 29318 | `@whatsapp_*` |
| discord | `mautrix/discord:v0.7.7` | 29334 | `@discord_*` |
| gmessages | `mautrix/gmessages:v26.09` | 29336 | `@gmessages_*` |
| messenger | `mautrix/meta:v26.09` | 29321 | `@messenger_*` |
| instagram | `mautrix/meta:ig-v26.09` | 29322 | `@instagram_*` |

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

Backed up: the six stateful volumes, `/var/lib/kanidm`, `/var/lib/homelab` and `/var/lib/syncthing`
(not stopped: a file mid-sync is caught next night). restic runs in a
container so the paths inside the repository — `/data/<volume>`,
`/data/homelab` — are the ones the macOS and Debian hosts wrote, and the series
and its retention carry straight on. The stateful containers are stopped for
the snapshot (~30 s), and kanidm with them; RocksDB and SQLite both tear if copied live.

```
sudo modules/programs/server/backup/backup.sh              # run now
sudo modules/programs/server/backup/backup.sh snapshots    # any restic command passes through
sudo modules/programs/server/backup/backup.sh check
```

Restoring a single service: stop its unit, run the
[restore](#first-boot-and-restore) with only that service's mount and
`--include`, start it.

## Monitoring

| Layer | Watcher | Catches |
|---|---|---|
| services | Uptime Kuma → Discord | a service down while the box is up |
| the proxy VPS | Uptime Kuma, by `jia.opena0.net` (whoami, 22, 7777) | the proxy, its Tailscale leg or the exit node down |
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

Registered against this same forgejo. Jobs run on `forgejo-runner-dind`, a
rootless docker daemon in its own container, not on the host's: a job that
reaches its daemon is an unprivileged user in that container rather than root
on the box. The two share the `runner` network and nothing else is on it.

- The runner is registered as `https://git.opena0.net`, not `forgejo:3000`.
  Jobs clone from the registered address, and from inside the nested daemon
  only the public name resolves.
- `data/config.yml` keeps `container.network: ""` (a per-workflow network
  inside the nested daemon; `proxy` does not exist there), `docker_host: "-"`,
  `privileged: false` and `valid_volumes: []`.
- Images jobs pull live in the `forgejo-runner_dind` volume. It is a cache:
  not backed up, and safe to delete with the unit stopped.

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
