# proxy-jia-opena0 (proxy VPS)

A VPS in front of [`jia-opena0`](../homelab) over Tailscale: a Vultr High
Performance AMD instance in Melbourne (`vhp-1c-1gb-amd`), at `67.219.104.255`
and `2401:c080:2000:2476:5400:6ff:fee0:ccbb`. It forwards jia's public ports
as plain TCP; see [The proxy itself](#the-proxy-itself).

Same shape as the homelab: headless, `users/opena0`,
[`network-server.nix`](../../system/network-server.nix), sshd and Tailscale.
Differences below.

## Hosting

- **Melbourne**, the same city as jia. From a Telstra connection, Vultr and
  BinaryLane Melbourne both answer in about 4 ms. Vultr takes Telstra domestic
  transit directly (a `twi…lnk.telstra.net` hop). BinaryLane is reached
  through Superloop, which is also its only IPv6 upstream. Telstra barely
  peers, so the direct link is the one that matters.
- **High Performance, not High Frequency**: same $6 for 1 GB, but 2 TB of
  transfer rather than 1 TB. Every byte jia serves passes through this box,
  and forwarding it needs no CPU clock.
- **1 GB**, which rules out nixos-anywhere's kexec step (it needs 1.5 GB), so
  the install boots the NixOS ISO instead. Vultr resizes plans up but never
  down, so taking 2 GB just for the install would mean paying for it for good.

## Install: nixos-anywhere and disko

The VPS boots the NixOS minimal ISO from Vultr's *Custom ISO* option, and
[nixos-anywhere](https://github.com/nix-community/nixos-anywhere) installs over
SSH to that live system: it partitions the disk with
[disko](https://github.com/nix-community/disko) and installs this flake's
output. Redeploying the box is the same steps again.

### Host config

- [`disko.nix`](disko.nix) partitions `/dev/vda` (check with `lsblk` on the
  live ISO): a BIOS boot partition *and* an ESP, so the same layout boots
  whether the instance comes up in BIOS or UEFI. disko provides `fileSystems`
  and `boot.loader.grub.devices`.
- [`hardware.nix`](hardware.nix) is written by hand, not generated: a KVM guest
  only needs the qemu-guest profile.
- GRUB rather than systemd-boot, installed to the removable EFI path so nothing
  depends on the firmware's NVRAM. That conflicts with
  `efi.canTouchEfiVariables`, which is why `system/boot/systemd-boot.nix` isn't
  imported.

### Host key and secrets

The host decrypts `secrets.yaml` with its SSH host key, so the key is made
before the box exists and injected by the install. Secrets then decrypt on the
first boot, with no second pass through `.sops.yaml`.

```
mkdir -p ~/proxy-hostkey/etc/ssh
ssh-keygen -t ed25519 -N "" -C "" -f ~/proxy-hostkey/etc/ssh/ssh_host_ed25519_key
nix shell nixpkgs#ssh-to-age -c ssh-to-age < ~/proxy-hostkey/etc/ssh/ssh_host_ed25519_key.pub
```

Add that recipient to [`.sops.yaml`](../../../.sops.yaml) as `&proxy-jia-opena0`
and to the proxy's creation rule, then, with a YubiKey plugged in:

```
sops updatekeys modules/hosts/proxy/secrets.yaml
```

Commit `.sops.yaml` and `secrets.yaml`. Keep `~/proxy-hostkey` out of the repo
and off anything synced; store the private key in Bitwarden so a redeploy keeps
the same recipient and `known_hosts` entry, then delete the directory after the
install.

### Deploy

1. **Add the ISO, then create the instance.** Vultr's ISO library has no
   NixOS, so add it under *Products → ISOs → Add ISO* from a remote URL.
   `https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso`
   redirects to a dated file on `releases.nixos.org`, so give Vultr the URL it
   redirects to (`curl -sI` shows it). The ISO's release doesn't matter,
   because the installed system comes from the flake. Then create the instance:
   Cloud Compute → High Performance → AMD, Melbourne, `vhp-1c-1gb-amd`,
   IPv6 on, with that ISO as the image.

2. **Open SSH on the live ISO** from Vultr's web console. The ISO boots logged
   in as `nixos`, with sshd installed but not started:

   ```
   sudo passwd root
   sudo systemctl start sshd
   ```

   Then, from the desktop, run `ssh-copy-id root@<ip>` with that password, and
   check the disk name matches `disko.nix`: `ssh root@<ip> lsblk`.

3. **Run nixos-anywhere** from the repo root on the desktop. Run only the disko
   and install phases: kexec isn't needed because the ISO already is the
   installer, and the reboot waits for step 4.

   ```
   nix run github:nix-community/nixos-anywhere -- \
     --flake .#proxy-jia-opena0 \
     --target-host root@<ip> \
     --extra-files ~/proxy-hostkey \
     --phases disko,install
   ```

   The desktop builds the system and copies it across. The box has too little
   RAM to build, and the Mac can't build `x86_64-linux`. **disko wipes the
   disk.**

4. **Set the sudo password** before leaving the ISO. `PermitRootLogin` is off
   and SSH is key-only, so this is the last point anything can set it:

   ```
   ssh -t root@<ip> "nixos-enter --root /mnt -c 'passwd opena0'"
   ```

5. **Remove the ISO** in Vultr (the instance's *Settings → Custom ISO*), which
   reboots it into the installed system. A plain `reboot` would come back up in
   the ISO.

### First boot

sshd listens on Tailscale only, so the box can't be reached over SSH until it
joins the tailnet. Log in as `opena0` in Vultr's web console with the password
from step 4, and run:

```
sudo tailscale up --hostname=proxy-jia-opena0
```

Then, from the desktop:

```
ssh-keygen -R <ip>
ssh proxy
git clone https://github.com/on9au/nixos ~/nixos
sudo ls /run/secrets    # once a module declares a secret; absent until then
```

`ssh-keygen -R` drops the live ISO's host key from the deploy.

The checkout has to be at `/home/opena0/nixos`: `dotfiles.link` resolves against
`$HOME/nixos`, and the live-linked nvim and tmux config dangle without it.
Cloned as `opena0`, it needs no `chown`.

Rebuild from the desktop, not on the box: evaluating home-manager and neovim in
1 GB runs out of memory. `opena0` is in `wheel`, so it is a trusted user and
can receive the closure. nh asks for the sudo password over SSH:

```
nh os switch -H proxy-jia-opena0 --target-host proxy
```

### Redeploying

Delete the `proxy-jia-opena0` node in the Tailscale admin console first, or the
new install joins as `proxy-jia-opena0-1`. Restore `~/proxy-hostkey` from
Bitwarden, attach the ISO again (*Settings → Custom ISO*), and run
[Deploy](#deploy) from step 2. `.sops.yaml` doesn't change.

## SSH

Port 7456 on `tailscale0` only, like the homelab, and `ssh proxy` from the
[`programs/tools/ssh`](../../programs/tools/ssh/home.nix) block. Public 22
belongs to Forgejo. When Tailscale is down, the way in is Vultr's web console
with `opena0`'s password. nixos-anywhere talks to the live ISO's sshd, so
none of this applies to the install.

The same non-empty `authorizedKeys` assertion applies; see the homelab README.

## Secrets

sops-nix, with its own [`secrets.yaml`](secrets.yaml) and the same workflow as
the [homelab](../homelab/README.md#secrets). The host's recipient goes into
`.sops.yaml` before the install, not after — see
[Host key and secrets](#host-key-and-secrets).

## The proxy itself

[`programs/server/haproxy.nix`](../../programs/server/haproxy.nix) forwards
TCP to jia over Tailscale. It doesn't terminate anything:

| Public | jia | PROXY header |
| --- | --- | --- |
| 80 | 80 | no: Caddy's HTTP→HTTPS redirect server takes no listener wrappers |
| 443 | 443 | v2, so Caddy logs and passes on the real client address |
| 22 | 2222 (Forgejo SSH) | no |
| 7777 | 7777 (Terraria) | no: tshock can't read one |

- **Why plain TCP, not a second Caddy here?** jia's Caddy already holds the
  certificates and builds its routes from container labels. A TLS-terminating
  proxy here would need the Cloudflare token on a public box and a copy of the
  routing. As it is, the box holds no state or secrets: losing it loses
  nothing, and a redeploy is the install again.
- **Caddy trusts PROXY headers from `172.18.0.1` only** (labels in
  [`caddy/`](../../programs/server/caddy/default.nix)). Tailscale masquerades
  what it forwards out of `tailscale0`, so the proxy's connections reach the
  container from the `proxy` network's gateway rather than from its `100.x`
  address. A header from anywhere else is ignored, so traffic still arriving
  through the router works too. If the network is ever recreated on another
  subnet, client addresses fall back to the gateway's rather than breaking.
- **No HTTP/3.** HAProxy forwards TCP only, so Caddy is set to `h1 h2` and
  stops advertising QUIC to clients.
- Forgejo SSH and Terraria see every client as `172.18.0.1` or docker's
  default gateway.
- haproxy resolves jia through MagicDNS at runtime (`init-addr none`), so it
  starts before Tailscale is up and follows jia to a new address after a
  reinstall.

Public DNS: `jia.opena0.net` (A and AAAA) points here, **DNS only (grey
cloud)**, since Cloudflare's proxy can't carry 22 or 7777. Every service's
CNAME follows it.
