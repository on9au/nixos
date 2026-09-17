# proxy-jia-opena0 (proxy VPS)

A VPS to sit in front of [`jia-opena0`](../homelab) over Tailscale, planned as a
Vultr High Frequency instance. Not deployed yet: the host config is ready to
install, but no reverse proxy is configured.

Same shape as the homelab: headless, `users/opena0`,
[`network-server.nix`](../../system/network-server.nix), sshd and Tailscale.
Differences below.

## Install: nixos-anywhere and disko

There is no installer ISO. The VPS is deployed with a stock Debian image, and
[nixos-anywhere](https://github.com/nix-community/nixos-anywhere) replaces it
over SSH: it kexecs into a NixOS installer running in RAM, partitions the disk
with [disko](https://github.com/nix-community/disko), installs this flake's
output and reboots. Redeploying the box is the same command again.

### Host config

- [`disko.nix`](disko.nix) partitions `/dev/vda` (check with `lsblk` on the
  Debian image): a BIOS boot partition *and* an ESP, so the same layout boots
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

1. **Create the instance** in Vultr: High Frequency, Debian, IPv6 on, and your
   SSH key added under *SSH Keys*. The installer runs from RAM, so pick a plan
   with at least 2 GB. If Vultr won't take the `sk-ssh-ed25519` key, log in as
   root from the web console and append it to `/root/.ssh/authorized_keys`.

2. **Check root SSH** works: `ssh root@<ip> lsblk` — and confirm the disk
   name matches `disko.nix`.

3. **Run nixos-anywhere** from the repo root, without the reboot phase:

   ```
   nix run github:nix-community/nixos-anywhere -- \
     --flake .#proxy-jia-opena0 \
     --target-host root@<ip> \
     --extra-files ~/proxy-hostkey \
     --build-on remote \
     --phases kexec,disko,install
   ```

   `--build-on remote` has the VPS build the system: the Mac can't build
   `x86_64-linux`. From the desktop, it can be left off. **disko wipes the
   disk.**

4. **Set the sudo password** before rebooting. `PermitRootLogin` is off and SSH
   is key-only, so this is the last point anything can set it. The installer
   kept root's `authorized_keys`, but has a new host key:

   ```
   ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@<ip>
   nixos-enter --root /mnt -c 'passwd opena0'
   reboot
   ```

### First boot

```
ssh-keygen -R <ip>
ssh opena0@<ip>
git clone https://github.com/on9au/nixos ~/nixos
sudo tailscale up --hostname=proxy-jia-opena0
sudo ls /run/secrets    # populated if the injected host key matches .sops.yaml
```

The checkout has to be at `/home/opena0/nixos`: `dotfiles.link` resolves against
`$HOME/nixos`, and the live-linked nvim and tmux config dangle without it.
Cloned as `opena0`, it needs no `chown`.

From here on, rebuild on the box with `nh os switch`.

### Redeploying

Delete the `proxy-jia-opena0` node in the Tailscale admin console first, or the
new install joins as `proxy-jia-opena0-1`. Restore `~/proxy-hostkey` from
Bitwarden and run [Deploy](#deploy) again — `.sops.yaml` doesn't change.

## SSH

Default port 22, unlike the homelab's 7456 — nothing connects here yet, so
there is no client config to match. Add a `proxy` block to
[`programs/tools/ssh`](../../programs/tools/ssh) when the box exists, and set
`services.openssh.ports` here to match if you move it. nixos-anywhere talks to
Debian's sshd, so the port only matters after the first boot.

The same non-empty `authorizedKeys` assertion applies; see the homelab README.

## Secrets

sops-nix, with its own [`secrets.yaml`](secrets.yaml) and the same workflow as
the [homelab](../homelab/README.md#secrets). The host's recipient goes into
`.sops.yaml` before the install, not after — see
[Host key and secrets](#host-key-and-secrets).

## The proxy itself

No reverse proxy is configured. It belongs in a new `modules/programs/server/`
tree — flat `.nix` per service, since these have no home-manager half — with
the TLS and upstream credentials in `secrets.yaml`.
