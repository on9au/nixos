# Working in this repo

A Nix flake for four machines: NixOS on `DESKTOP-DYLAN` and `LAPTOP-ON9AU`,
NixOS-WSL on `G3JC7G4`, nix-darwin on `MBP-DYLAN`, with home-manager as a
module on all of them. `README.md` is the reference for *why* configs look the
way they do.

## Layout

| path | what |
| --- | --- |
| `hosts/<host>/` | one machine |
| `modules/nixos/common.nix` | every NixOS machine |
| `modules/nixos/desktop.nix` | the Hyprland desktop (both bare-metal machines) |
| `modules/common/` | shared by NixOS and nix-darwin |
| `home/default.nix` | shell half — every machine |
| `home/desktop.nix` | Hyprland half |
| `home/darwin.nix` | macOS half |
| `dotfiles/` | the config files themselves |

Which `home/*.nix` a host imports is what decides where a config lands.

## `dotfiles/config` is live

Configs under `dotfiles/config` and `dotfiles/local-bin` are linked with
`config.lib.dotfiles.link`, an out-of-store symlink to the checkout at
`~/nixos`. Edits apply immediately, without a rebuild, and files that apps
write (`lazy-lock.json`, `lazyvim.json`, `karabiner.json`) land
in `git status`. Don't switch these to `source = ./...` — that copies them into
the store and breaks both.

The exception: `dotfiles/zsh/*` and `dotfiles/tmux/tmux.conf` are read with
`builtins.readFile` into home-manager's generated files, so they need a
rebuild.

## Checking a change

- A flake only sees files git knows about. `git add` new files first.
- NixOS: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`.
- Mac: `nix eval --raw .#darwinConfigurations.MBP-DYLAN.system.drvPath`
  evaluates on Linux; it cannot be built here.
- `LAPTOP-ON9AU` is only a flake output once
  `hosts/LAPTOP-ON9AU/hardware-configuration.nix` exists.
- Hyprland: `Hyprland --verify-config -c ~/nixos/dotfiles/config/hypr/hyprland.lua`.
- Switching needs sudo and a TTY. Build, and leave the switch to the user.

## Gotchas

- `hypr/host.lua` and `uwsm/env` choose per-machine settings from
  `/proc/sys/kernel/hostname`. Unknown hostnames get the desktop's.
- Unfree packages go in `unfree.allow`. `allowUnfreePredicate` is set once in
  `modules/common/unfree.nix` because it does not merge.
- `hyprpolkitagent` stays in `environment.systemPackages`: autostart starts it
  as a user unit, and units from `home.packages` are not linked.
- hypridle is started by `hypr/autostart.lua`. Enabling `services.hypridle`
  too runs two.
- `lazy-lock.json` is committed and written by nvim. Scripts use
  `nvim --headless "+Lazy! restore" +qa`, never `Lazy! sync`.
- The Hyprland config is Lua, so `hyprctl dispatch` takes `hl.dsp.*`; the
  classic syntax is a parse error.
- Run `nix flake lock`/`update` as the user. A `sudo` run leaves `flake.lock`
  root-owned.

## Style

Comments only where the reason is not obvious, and short.
