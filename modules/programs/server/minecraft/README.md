# Minecraft servers

Fabric servers on the desktop, built by
[nix-minecraft](https://github.com/Infinidoge/nix-minecraft), each behind
[lazymc](https://github.com/timvisee/lazymc). lazymc holds the server's port,
lists it as sleeping, starts it when someone joins and stops it once it has sat
empty. Players connect to the proxy VPS, whose haproxy passes the port on to
the desktop over Tailscale ([The proxy itself](../../hosts/proxy/README.md#the-proxy-itself)).

Each server is an entry in [`servers.nix`](servers.nix) (port, heap,
whitelist, `server.properties`) and a [packwiz](https://packwiz.infra.link/)
pack in `servers/<name>/`, which holds its game version and mods. The memory
caps are in [`default.nix`](default.nix). The desktop has to be on: leave it in
server mode (power menu) rather than shut down.

## Mods

From `servers/<name>/`:

```
packwiz modrinth add <slug or URL>   # adds its dependencies too
packwiz remove <slug>
packwiz update --all                 # or one slug
git add .                            # the flake only sees files git knows
```

Then build and switch; the server picks the new mods up when it next starts.
Modrinth only: packwiz records no download URL for a CurseForge mod, and the
build stops on it. Mods marked client-only in their `.pw.toml` (`side`) stay
out of the server, so the same pack can carry them for players.

## Add a server

1. `mkdir servers/<name> && cd servers/<name>`, then
   `packwiz init --name <name> --author on9au --version 1.0.0 --mc-version <version> --modloader fabric --fabric-latest`,
   and add its mods as above. The game version has to be one nix-minecraft
   has: `pkgs.fabricServers.fabric-<version with _>`.
2. Add it to [`servers.nix`](servers.nix) with an unused port.
3. Build and switch the desktop, then
   [redeploy the proxy](../../hosts/proxy/README.md#redeploying) for the new
   port.
4. Give it a name, below.

## Names

Each server has its own port, and an SRV record in Cloudflare (DNS only) lets
players type a name instead:

| Type | Name | Priority, weight | Port | Target |
| --- | --- | --- | --- | --- |
| SRV | `_minecraft._tcp.<name>` | 0, 0 | its port | `jia.opena0.net` |

Then `<name>.opena0.net` reaches that server. The server on 25565 also answers
on plain `jia.opena0.net`. On the home network, join on the desktop's LAN
address and the port instead; that skips the trip out to the VPS and back.

## Whitelist

`whitelist = true` in [`servers.nix`](servers.nix) lets in only the players in
[`players.nix`](players.nix), and lazymc won't wake the server for anyone
else. With it on and `players.nix` empty, nobody gets in.

## Running them

```
systemctl status minecraft-server-<name>        # lazymc, and the server under it when awake
journalctl -u minecraft-server-<name> -f
echo 'list' > /run/minecraft/<name>.stdin       # a console command (as root), awake only
sudo systemctl restart minecraft-server-<name>  # also picks up a changed server.properties
```

Worlds and everything the server writes are under `/srv/minecraft/<name>`.
Only btrbk's hourly snapshots of `/` cover them; the restic backup is `/home`
only.

Every player shows up as the proxy's address: lazymc can't read the PROXY
header that would carry theirs. Ban by name, not IP.
