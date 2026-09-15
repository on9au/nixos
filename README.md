# nixos

its  ~~claude's~~ *my* nixos conf

NixOS, nix-darwin and home-manager, one flake. This used to be a chezmoi repo
([on9au/dotfiles](https://github.com/on9au/dotfiles), branch `hyprland`, has
that history — including the old GlazeWM config, `git log -- dot_glzr`).

| machine | OS | host module | window manager |
| --- | --- | --- | --- |
| `DESKTOP-DYLAN` | NixOS | [`modules/hosts/desktop`](modules/hosts/desktop) | Hyprland |
| `LAPTOP-ON9AU` | NixOS (Arch until reinstalled) | [`modules/hosts/laptop`](modules/hosts/laptop) | Hyprland |
| `MBP-DYLAN` | macOS + nix-darwin | [`modules/hosts/macbook`](modules/hosts/macbook) | AeroSpace |
| `G3JC7G4` | NixOS-WSL | [`modules/hosts/wsl`](modules/hosts/wsl) | none — shell only |
| `jia-opena0` | NixOS (Debian until migrated) | [`modules/hosts/homelab`](modules/hosts/homelab) | none — headless |
| `proxy-jia-opena0` | NixOS (not built yet) | [`modules/hosts/proxy`](modules/hosts/proxy) | none — headless |

## Layout

```
flake.nix
modules/
  hosts/        one folder per machine: what it imports, its hardware config and notes
  system/       base NixOS settings (boot, filesystems, network, nix); darwin/ for the Mac
  hardware/     gpu, peripherals, power, firmware
  devices/      per-device quirks, e.g. the Apple USB-C dongle's audio rules
  programs/     apps, desktop, development, games, macos, server, services, tools
  users/        the djpro and opena0 accounts
  home-manager/ home-manager wiring
```

A program with home-manager config is a folder: `default.nix` for the system
side, `home.nix` for home-manager, and its hand-written config files beside
them. **Those config files are live** — `~/.config/<app>` is a symlink into this
checkout at `~/nixos`, so an edit applies without a rebuild. `AGENTS.md` has the
conventions.

## Install

Clone to `~/nixos` first — the config links point there.

| machine | first switch |
| --- | --- |
| NixOS | `sudo nixos-rebuild switch --flake ~/nixos#<host>` |
| Mac | install Nix and Homebrew, then `sudo nix run nix-darwin -- switch --flake ~/nixos#MBP-DYLAN`; afterwards `sudo darwin-rebuild switch --flake ~/nixos` |
| WSL | import the NixOS-WSL tarball, then the NixOS command with `#G3JC7G4` |
| laptop | during the install, write `modules/hosts/laptop/hardware.nix` and `git add` it — the output does not exist until then |
| servers | same as the laptop: write `modules/hosts/{homelab,proxy}/hardware.nix` during the install and `git add` it. Both boxes need the repo cloned to `/home/opena0/nixos`. SSH is YubiKey-only (password auth is off), and after the first boot the host's key goes into `.sops.yaml` — see the homelab README |

After the first switch, rebuild with `nh os switch` (NixOS) or `nh darwin switch`
(Mac). nh already knows the flake is at `~/nixos`, and `nh clean` runs weekly,
keeping the last 30 days and at least 5 generations.

### Coming from chezmoi

On a machine chezmoi set up, the first switch finds real files where
home-manager wants links and moves each aside as `<name>.chezmoi-bak`. Then:

- `nix run nixpkgs#chezmoi -- purge`, so a stray `chezmoi apply` cannot
  overwrite the links
- move `~/.gitconfig` aside: `gh auth setup-git` wrote a `/nix/store` path into
  it, and it overrides `programs.git`
- delete what chezmoi wrote that nothing replaces: `~/.tmux.conf` (tmux still
  loads it, tpm and all), `~/.tmux`, `~/.zsh_plugins.txt`, `~/.antidote`,
  `~/.config/environment.d/10-ssh-agent.conf`, `~/.config/spotify-launcher.conf`
- delete the `.chezmoi-bak` files once nothing in them is missing from the repo

## Notes

| topic | where |
| --- | --- |
| Hyprland: layout, monitors, keys, idle, HiDPI | [`programs/desktop/hyprland`](modules/programs/desktop/hyprland/README.md) |
| Login screen | [`programs/desktop/greetd`](modules/programs/desktop/greetd/README.md) |
| Waybar tray and KDE Connect | [`programs/desktop/waybar`](modules/programs/desktop/waybar/README.md) |
| GTK apps and theme | [`programs/desktop/general`](modules/programs/desktop/general/README.md) |
| Input method (fcitx5) | [`programs/desktop/input-method.md`](modules/programs/desktop/input-method.md) |
| Keyring, SSH agent, YubiKeys, sops identities | [`programs/services/ssh-agent`](modules/programs/services/ssh-agent/README.md) |
| Neovim and marie-lsp | [`programs/development/neovim`](modules/programs/development/neovim/README.md) |
| Karabiner | [`programs/macos/karabiner`](modules/programs/macos/karabiner/config/README.md) |
| Laptop: hybrid graphics | [`hosts/laptop`](modules/hosts/laptop/README.md) |
| Laptop: whole-machine NVMe freezes | [`hosts/laptop/nvme-vmd-stalls.md`](modules/hosts/laptop/nvme-vmd-stalls.md) |
| MacBook: bring-up, keyboard, bar, defaults | [`hosts/macbook`](modules/hosts/macbook/README.md) |
| WSL | [`hosts/wsl`](modules/hosts/wsl/README.md) |
| Homelab: services, install and restore, bridges, backups, secrets | [`hosts/homelab`](modules/hosts/homelab/README.md) |
| Proxy VPS: boot loader, what is still missing | [`hosts/proxy`](modules/hosts/proxy/README.md) |
