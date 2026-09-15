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

Both YubiKeys' resident keys are in [`users/opena0`](../../users/opena0/default.nix),
shared with the proxy, so the assertion passes; it stays to catch the list being
emptied by mistake.

## Not imported, deliberately

`filesystems/btrfs.nix` schedules a scrub of `/` and would fail on any other
filesystem, so add it only if the install is btrfs.

`system/network.nix` is NetworkManager; this host takes
[`network-server.nix`](../../system/network-server.nix) — systemd-networkd
plus resolved, since there is no user session to hand link management to.

## Secrets

sops-nix. This host's file is [`secrets.yaml`](secrets.yaml), set as
`sops.defaultSopsFile`; edit it from the repo root with either YubiKey plugged
in ([which ones](../../programs/services/ssh-agent/README.md#age-identities-for-sops)):

```
sops modules/hosts/homelab/secrets.yaml
```

Declare a secret next to the service that uses it, and hand the service
`config.sops.secrets.<name>.path` — through a `*File` option, `EnvironmentFile=`
or `LoadCredential=`. Never the value as a Nix string: the store is
world-readable and the repo is public. For a service with no file option,
`sops.templates` renders its whole config with the secrets substituted.

**The host can't decrypt anything until its key is in `.sops.yaml`.** sops-nix
uses `/etc/ssh/ssh_host_ed25519_key`, which doesn't exist until the machine has
booted once, so the first switch goes out with no secrets declared. Then get the
host's age recipient, on the box or from anywhere on the tailnet:

```
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
ssh-keyscan -p 7456 -t ed25519 jia-opena0 | ssh-to-age
```

Add it under `keys:` in [`.sops.yaml`](../../../.sops.yaml) and to the homelab
rule's `age:` list, re-encrypt, and commit:

```
sops updatekeys modules/hosts/homelab/secrets.yaml
```

A reinstall that doesn't carry `/etc/ssh` over makes a new host key and needs
the same again. Until then, a declared secret fails at activation.
