# Working in this repo

A NixOS + nix-darwin + home-manager flake for four machines. `README.md` is the
short overview; the notes on *why* something is configured the way it is live
in a `README.md` next to the module they describe.

## Hosts

| flake output | module | machine |
| --- | --- | --- |
| `DESKTOP-DYLAN` | `modules/hosts/desktop` | NixOS desktop |
| `LAPTOP-ON9AU` | `modules/hosts/laptop` | NixOS laptop — only an output once `hardware.nix` exists |
| `G3JC7G4` | `modules/hosts/wsl` | NixOS-WSL, shell half only |
| `MBP-DYLAN` | `modules/hosts/macbook` | nix-darwin |

Input modules (home-manager, lanzaboote, nix-flatpak, nixos-wsl) are added per
host in `flake.nix`.

## Layout

- `modules/hosts/<host>/` — `default.nix` imports what the machine uses, grouped
  under short section comments; `hardware.nix` is the generated hardware config.
- `modules/system/` — base NixOS modules. `default.nix` (locale, nix settings,
  options) goes on every NixOS host; `boot/`, `filesystems/`, `network.nix`,
  `zram.nix` are imported per host. `system/darwin/` is the nix-darwin base.
- `modules/hardware/` — `gpu/`, `peripherals/`, `power/`, `firmware/`, one
  concern per file, imported per host.
- `modules/devices/` — one file per physical device (e.g. WirePlumber rules).
- `modules/programs/{apps,desktop,development,games,macos,services,tools}/`.
- `modules/users/djpro/` — `default.nix` (NixOS), `darwin.nix`, and `home.nix`
  (shared git identity).
- `modules/home-manager/` — home-manager wiring (`default.nix`) and base config
  (`common.nix`, which defines `config.lib.dotfiles.link`).

## Program modules

- System-only: a flat `name.nix`.
- With home-manager config: a folder with `default.nix` (system side, ending in
  `homeManagerModules = [./home.nix];`) and `home.nix`.
- Hand-written config files sit in that folder (`config/`, `bin/`, single
  files) in their native format. Don't port them to Nix unless asked.
- Add home-manager config through `homeManagerModules` only — paths or inline
  modules (hosts set `home.stateVersion` inline). Don't write
  `home-manager.users.<name>`.
- nix-darwin can't import a `default.nix` that sets NixOS-only options
  (`services.*`, `users.defaultUserShell`, Linux-only `environment.systemPackages`).
  The macbook host lists those modules' `home.nix` directly in
  `homeManagerModules`, so keep `home.nix` files platform-agnostic
  (`lib.optionals stdenv.hostPlatform.isLinux`).
- `programs/macos/*` modules declare their own Homebrew taps/casks/brews.

## Live config links

`config.lib.dotfiles.link ./path` makes an out-of-store symlink into the
checkout at `~/nixos`, worked out from the module's own path. Edits apply
without a rebuild, and files apps write (`lazy-lock.json`, `lazyvim.json`,
`karabiner.json`, `mimeapps.list`) show up in `git status`. Don't switch these to
`source = ./path` — that copies into the store.

Exceptions, read with `builtins.readFile` and so needing a rebuild:
`programs/tools/zsh/*.zsh` and `programs/tools/tmux/tmux.conf`.

## Custom options

`modules/system/nix/options.nix`: `primaryUser`, `greeterWallpaper`,
`homeManagerModules`. Add repo-wide options there.

## Style

- Format with `nix fmt .` (alejandra). Without the `.`, alejandra waits on stdin.
- `{...}:` when a module uses no arguments; `name = value;` rather than `inherit`.
- Lists sorted alphabetically unless order matters — then
  `# nix-style: ignore-order` directly above.
- `with pkgs;` for package lists.
- Comments only for a non-obvious why: a workaround, a conflict with another
  module, surprising behaviour. App lists keep one short comment per entry on
  what the app is for.
- Never bump `system.stateVersion` or `home.stateVersion`.

## Checking a change

- A flake only sees files git knows about: `git add` first.
- NixOS: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`.
- Mac: `nix eval --raw .#darwinConfigurations.MBP-DYLAN.system.drvPath` (evaluates
  on Linux, can't be built here).
- Laptop: evaluate with a stub `modules/hosts/laptop/hardware.nix`, then delete it.
- Hyprland: `Hyprland --verify-config -c ~/nixos/modules/programs/desktop/hyprland/config/hypr/hyprland.lua`.
- Switching needs sudo and a TTY. Build, and leave the switch to the user.

## Gotchas

- `hypr/host.lua` and `uwsm/env` pick per-machine settings from
  `/proc/sys/kernel/hostname`; unknown hostnames get the desktop's.
- `hyprpolkitagent` stays in `environment.systemPackages`: autostart starts it
  as a user unit, and units from `home.packages` aren't linked.
- hypridle is started by `hypr/autostart.lua`. Enabling `services.hypridle` too
  runs two.
- `lazy-lock.json` is committed and written by nvim. Scripts use
  `nvim --headless "+Lazy! restore" +qa`, never `Lazy! sync`.
- The Hyprland config is Lua, so `hyprctl dispatch` takes `hl.dsp.*`.
- waybar tracks git HEAD (`waybar` flake input); `nix flake update waybar` can
  break its build when upstream adds a dependency.
- Run `nix flake lock`/`update` as the user; a `sudo` run leaves `flake.lock`
  root-owned.
- The GTK/KDE preference: GTK apps, portal and theme; KDE Connect is the one
  deliberate Qt/KDE exception.
