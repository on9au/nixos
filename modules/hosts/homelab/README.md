# jia-opena0 (homelab)

The homelab server, moving from Debian to NixOS. Headless: no compositor, no
`programs/desktop` imports, and `users/opena0` rather than `users/djpro` —
the account name the Debian box already used, and the one the `jia` block in
[`programs/tools/ssh`](../../programs/tools/ssh) connects as.

## Install

`nixos-generate-config` can't be run from the Debian side. Boot the NixOS
installer, then:

```
nixos-generate-config --root /mnt --show-hardware-config > modules/hosts/homelab/hardware.nix
git add modules/hosts/homelab/hardware.nix
```

The `jia-opena0` flake output does not exist until that file is committed —
same `builtins.pathExists` guard the laptop uses.

Clone the repo to `/home/opena0/nixos` on the box. `dotfiles.link` resolves
against `$HOME/nixos`, so the live-linked nvim and tmux config depend on the
checkout being there; without it those symlinks dangle.

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

Fill in the YubiKey resident key's public half. `ssh-keygen -K` re-emits it on
any machine holding the token, so it never needs copying between hosts.

## Not imported, deliberately

`filesystems/btrfs.nix` schedules a scrub of `/` and would fail on any other
filesystem, so add it only if the install is btrfs.

`system/network.nix` is NetworkManager; this host takes
[`network-server.nix`](../../system/network-server.nix) — systemd-networkd
plus resolved, since there is no user session to hand link management to.

## Still missing: secrets

Nothing in this repo manages secrets. The store is world-readable and the
repo is public, so anything with a password, token or ACME credential needs
`sops-nix` or `agenix` added as a flake input first. Decide that before
writing the first service module in `programs/server/`.
