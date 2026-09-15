# proxy-jia-opena0 (proxy VPS)

A VPS to sit in front of [`jia-opena0`](../homelab) over Tailscale. Not built
yet — this is the skeleton, so the host evaluates and the shell environment is
ready before the box is provisioned.

Same shape as the homelab: headless, `users/opena0`,
[`network-server.nix`](../../system/network-server.nix), sshd and Tailscale.
Differences below.

## Boot loader

Imported as `systemd-boot`, which every current VPS provider supports. If the
image turns out to be BIOS-only, swap that import for

```nix
boot.loader.grub.devices = ["/dev/…"];
```

Leaving it unset is not an option: NixOS defaults to GRUB and fails to
evaluate with *"You must set the option `boot.loader.grub.devices`"*.

## SSH

Default port 22, unlike the homelab's 7456 — nothing connects here yet, so
there is no client config to match. Add a `proxy` block to
[`programs/tools/ssh`](../../programs/tools/ssh) when the box exists, and set
`services.openssh.ports` here to match if you move it.

The same non-empty `authorizedKeys` assertion applies; see the homelab README.

## The proxy itself

No reverse proxy is configured. It belongs in a new `modules/programs/server/`
tree — flat `.nix` per service, since these have no home-manager half — and
needs secret management (`sops-nix` or `agenix`) in place first for TLS and any
upstream credentials.
