# Working in this repo

Read [`CONVENTIONS.md`](CONVENTIONS.md) before changing anything, and
[`README.md`](README.md) for the hosts, installing and secrets. What follows is
only what applies to an agent and not to the person at the keyboard.

@CONVENTIONS.md

## For agents

- Build and check, but leave the switch to the user: it needs sudo and a TTY.
- Leave `sops` itself to the user; editing a secret needs a YubiKey touch.
- Keep hand-written config files in their native format unless asked to port
  them to Nix.
