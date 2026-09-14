# Keyring, SSH agent and YubiKeys

## Keyring (secrets, git credentials, ssh)

Nothing on this machine implemented the freedesktop **Secret Service** until
now. gnome-keyring was never installed, and the `kwallet` left over from the
KDE days only registers `org.kde.secretservicecompat` — a different bus name,
which nothing outside KDE looks for. So every app that stores a password hit:

```
GDBus.Error:org.freedesktop.DBus.Error.ServiceUnknown: The name is not activatable
```

Chromium, Brave, Electron apps and `git-credential-libsecret` all ask for
`org.freedesktop.secrets` by name; with no owner they either fall back to
storing secrets in plaintext or fail outright. gnome-keyring rather than
kwallet, because the rest of this session is deliberately not KDE.

`services.gnome.gnome-keyring` plus `enableGnomeKeyring` on the `greetd` and
`passwd` PAM services, in `programs/services/keyring.nix`.

**The unlock has to come from PAM.** A systemd user unit can start the daemon
but cannot unlock the keyring without prompting for a password, and the only
password typed at login is the one PAM already has. Most instructions patch
the sddm or gdm PAM service; this machine has neither — **greetd authenticates
through its own `greetd` service**, so that is the one that gets
`pam_gnome_keyring.so`. `passwd` gets it too, otherwise changing the login
password with `passwd` leaves the keyring encrypted under the old one and the
next login shows an "Unlock Login Keyring" dialog for a password that no longer
exists.

The module is `optional`: a keyring that will not unlock can never block a
login.

The keyring is created on the **next full login**, not by the rebuild — log out
and back in rather than just unlocking hyprlock. Then:

```bash
busctl --user list | grep secrets   # org.freedesktop.secrets, owned
secret-tool store --label=test test key   # optional round-trip check
secret-tool lookup test key
```

git over HTTPS to GitHub authenticates through `gh`
(`programs.gh.gitCredentialHelper`), not the keyring. gcr-ssh-agent stays off
(`services.gnome.gcr-ssh-agent.enable = false`) — see "SSH agent and YubiKeys"
below.

`gh` itself is not covered by the keyring — it keeps its token in
`~/.config/gh/hosts.yml` in plaintext and has no libsecret backend.

## SSH agent and YubiKeys

SSH keys live on two YubiKey 5C NFCs as FIDO2 keys — `sk-ssh-ed25519`, one per
key, `id_ed25519_sk_primary` and `id_ed25519_sk_backup`. The private half never
leaves the device; what sits in `~/.ssh` is only a *handle*, useless without the
YubiKey that made it. Every authentication needs a physical touch.

**Which agent, and why it changed.** gcr-ssh-agent was the answer while keys
were ordinary files on disk (see Keyring above). It cannot hold these:
gcr-ssh-agent links no libfido2 and knows no `sk-*` key types. So it is
disabled and OpenSSH's own agent (`programs.ssh.startAgent`), which talks to
the key through `ssh-sk-helper`, took over.

**The socket path has to be named twice, and neither place is optional.**
The agent listens on `$XDG_RUNTIME_DIR/ssh-agent`, and NixOS exports
`SSH_AUTH_SOCK` from `/etc/profile` only — shells, never the systemd user
manager. The two readers of that variable are reached differently:

| File | Covers | Why the other one misses it |
| --- | --- | --- |
| `systemd.user.sessionVariables` in `home.nix` | the systemd user manager, so every graphical app and user unit | a shell never reads environment.d |
| `programs/tools/zsh/zshrc.zsh` | interactive shells, including SSHing *into* this machine | that login has no systemd user manager env to inherit |

Set in only one, the symptom is a partial one: `ssh` works in kitty and the
editor's git integration says `Connection refused`, or the reverse. Both files
carry the same value and the `.zshrc` line is guarded on the socket existing,
since WSL shares that file and has no such unit.

The old gcr path is stickier than it looks. `SSH_AUTH_SOCK` survives in the
systemd user environment after its unit is disabled, so a machine that has run
both will keep answering `/run/user/1000/gcr/ssh` until the next full login.
`systemctl --user show-environment | grep SSH_AUTH_SOCK` is the check;
`systemctl --user set-environment SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent"`
fixes the running session without logging out.

**One credential per key, both resident.** The two keys are genuinely two
devices — a backup generated on the primary would not be a backup at all, and
the handle files in `~/.ssh` look identical either way, so it is worth being
able to re-check:

| Handle | Fingerprint | Device |
| --- | --- | --- |
| `id_ed25519_sk_primary` | `SHA256:KYhxT8Wejm4/tJ2b++vMK3oKtRa6BiREOI/iAYDvFLY` | serial 38362833 |
| `id_ed25519_sk_backup` | `SHA256:3+++WT+/EMp5qBV1H8nsFVBQlcXdrxDhQPmJn1Zt3Qg` | serial 38362959 |

Both were generated `-O resident`, which is the property worth having: the
credential lives on the key itself, so `~/.ssh` is a convenience rather than
something whose loss costs the key. With exactly one key plugged in:

```bash
cd "$(mktemp -d)" && ssh-keygen -K && ssh-keygen -lf *.pub
```

downloads that key's credential (PIN, then touch) and prints its fingerprint —
which one comes back tells you which device is in your hand. It lands as
`id_ed25519_sk_rk`, no application suffix, because the application is exactly
`ssh:`. `ykman fido info` is the no-touch version: *Credential storage
remaining* differs per device (95 and 94 here — five and six credentials used,
the rest being website passkeys), so it distinguishes the two keys without
authenticating, but it cannot say *which* credentials those are.

Both `.pub` files go to GitHub and to every `authorized_keys` — while the old
`id_ed25519` still works, not after.

**A PIN prompt needs an askpass when there is no tty.** `ssh-keygen -K`, and
anything else that asks for a FIDO2 PIN, falls back to `$SSH_ASKPASS` when it
has no controlling terminal — from a GUI app, or from a tool driving the shell.
Unset, it defaults to an `ssh-askpass` that is usually not installed; the
failure is a misleading *"incorrect passphrase supplied
to decrypt private key"* for a passphrase it never managed to read. The same
helper the session already uses for sudo covers it — forced, for a one-off in a
terminal that would otherwise prompt inline:

```bash
SSH_ASKPASS="$(command -v ssh-askpass)" SSH_ASKPASS_REQUIRE=force ssh-keygen -K
```

(`command -v` rather than a literal path on purpose: the helper is not in the
same place on every machine.)

**ssh-agent is the worst case of this**, because it is a systemd unit and so
never has a tty at all — an sk key loaded with `ssh-add -K` cannot sign until
the agent has an askpass. The symptom is `agent refused operation` on the
client, with `sshkey_sign: incorrect passphrase supplied to decrypt private
key` in `journalctl --user -u ssh-agent`; neither points at a missing prompt.
Worse, it is silent about the cause: once the agent holds an identity, ssh uses
that copy and never falls back to the handle file on disk, so a broken agent
key shadows a working one. `ssh-add -D` is the quick way out.

`SSH_ASKPASS` is therefore set in `systemd.user.sessionVariables` and not only in `uwsm/env` —
the user manager starts the agent from its own environment, not the session's.

Note also that `ssh-keygen -Y sign` writes its signature next to the file being
signed, so signing `/dev/null` as a throwaway probe fails on `/dev/null.sig`
long after the interesting part — the touch — has already happened.

**Both handles are named under `Host *`, and the second key costs a wasted
touch.** ssh offers identities in the order they are listed, so with only the
backup plugged it offers the primary first — and a FIDO2 key insists on a touch
*before* it will admit it does not hold a credential, since enumerating a
YubiKey's credentials without authenticating is exactly what that rule prevents.
So: touch, failure, then the backup works. Reordering only moves which key pays.

This is accepted rather than fixed. The fix, if it becomes annoying, is the
agent — both credentials are resident, so it can hold only the key in hand:

```bash
ssh-add -K          # PIN + touch; loads the plugged key's resident credential
ssh-add -l          # exactly one sk key
```

That only helps once the `IdentityFile` lines are gone, though: a listed file is
offered whether or not the agent has it.

One side effect of listing them at all: an explicit `IdentityFile` *replaces*
the `~/.ssh/id_*` defaults rather than adding to them, so `id_ed25519` is no
longer offered to anything — GitHub included, which fails silently here because
this repo's remote is HTTPS through the gh credential helper. Both sk keys need to
be on GitHub and in every `authorized_keys`.

The file itself is not in this repo (it names hosts that need not be public,
and lives next to private keys).

`pcscd` is on, but only for Yubico Authenticator's OATH codes — FIDO2 goes over
hidraw and does not need it. Commit signing is still
GPG key `3FCF1E93FFC208B5` rather than the YubiKey.

