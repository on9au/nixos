# YubiKeys

Two YubiKey 5C NFCs. Each holds a resident FIDO2 SSH credential and, in its PIV
applet, an age identity that edits this repo's secrets. Either one alone does
everything; nothing needs one to build or activate a host.

| | primary | backup |
| --- | --- | --- |
| serial | 38362833 | 38362959 |
| SSH key | `SHA256:KYhxT8Wejm4/tJ2b++vMK3oKtRa6BiREOI/iAYDvFLY` | `SHA256:3+++WT+/EMp5qBV1H8nsFVBQlcXdrxDhQPmJn1Zt3Qg` |
| sops recipient | `age1yubikey1qdre4pf0uxer9vrxqpscx3jdthuwyd20tp8rqqv5lkvgvmuwmqs52kak3eu` | `age1yubikey1qwwajvh5ll93ns26nv59ug90qhq4fsf5zykzuwgwxt845ttng8745n0jtpv` |

## SSH

The client offers one file, `~/.ssh/id_ed25519_sk_rk`
([`programs/tools/ssh`](../../../programs/tools/ssh/home.nix)). It is a handle,
useless without the key that made it. Every host's sshd listens on 7456 and
takes only `sk-ssh-ed25519` keys
([`programs/services/sshd.nix`](../../../programs/services/sshd.nix),
[`system/darwin/sshd.nix`](../../../system/darwin/sshd.nix)). Both public keys
are in [`users/djpro/authorized_keys`](../../../users/djpro/authorized_keys),
and the opena0 user shares that file.

**On a new machine**, with one key plugged in (PIN, then touch):

```bash
cd ~/.ssh && ssh-keygen -K   # writes id_ed25519_sk_rk
ssh-keygen -lf id_ed25519_sk_rk.pub   # which key it is, against the table
```

On the Mac this needs nixpkgs' `ssh-keygen`, see
[its README](../../../hosts/macbook/README.md#yubikey-and-ssh).

**The touch happens where the key is plugged in**, so a second hop is
`ssh -J jia proxy`, not ssh from jia.

### When it fails

- **`agent refused operation`**, and `incorrect passphrase supplied to decrypt
  private key` in `journalctl --user -u ssh-agent`: the agent holds the key
  but had no way to ask for the PIN. An identity in the agent shadows the
  handle file, so `ssh-add -D` and try again.
- **A PIN prompt with no terminal** (a GUI app, a tool driving the shell) fails
  the same way. Force the askpass helper for a one-off:
  `SSH_ASKPASS="$(command -v ssh-askpass)" SSH_ASKPASS_REQUIRE=force ssh-keygen -K`.
- **ssh works in kitty but not from a GUI app, or the other way round**: the
  user manager and the shell disagree on `SSH_AUTH_SOCK`.
  `systemctl --user show-environment | grep SSH_AUTH_SOCK` should be
  `$XDG_RUNTIME_DIR/ssh-agent`. A session that once ran gcr-ssh-agent keeps
  its path until the next full login;
  `systemctl --user set-environment SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent"`
  fixes it in place.

## sops

Both recipients are on every rule in [`.sops.yaml`](../../../../.sops.yaml);
the workflow is in the [top-level README](../../../../README.md#secrets).
`~/.config/sops/age/keys.txt` holds what `age-plugin-yubikey --identity`
prints. Those lines name a serial and a slot, not key material, so the file
copies to any machine as is.

**Generating an identity needs a TDES management key.** Firmware 5.7 defaults
to AES192, which age-plugin-yubikey 0.5.1 can't use, and `--generate` fails
with *Failed to authenticate with the PIN-protected management key*
([str4d/age-plugin-yubikey#92](https://github.com/str4d/age-plugin-yubikey/issues/92)).
Decrypting never uses the management key:

```bash
ykman --device <serial> piv access change-management-key -a TDES --generate --protect
```
