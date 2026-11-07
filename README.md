# nixos

its  ~~claude's~~ *my* nixos conf

NixOS, nix-darwin and home-manager, one flake. This used to be a chezmoi repo
([on9au/dotfiles](https://github.com/on9au/dotfiles), branch `hyprland`, has
that history — including the old GlazeWM config, `git log -- dot_glzr`).

| machine (flake output) | OS | host module | window manager |
| --- | --- | --- | --- |
| `DESKTOP-DYLAN` | NixOS | [`modules/hosts/desktop`](modules/hosts/desktop) | Hyprland |
| `LAPTOP-ON9AU` | NixOS | [`modules/hosts/laptop`](modules/hosts/laptop) | Hyprland |
| `MBP-DYLAN` | macOS + nix-darwin | [`modules/hosts/macbook`](modules/hosts/macbook) | AeroSpace |
| `G3JC7G4` | NixOS-WSL, on the laptop's Windows | [`modules/hosts/wsl`](modules/hosts/wsl) | none — shell only |
| `jia-opena0` | NixOS | [`modules/hosts/homelab`](modules/hosts/homelab) | none — headless |
| `proxy-jia-opena0` | NixOS, Vultr VPS | [`modules/hosts/proxy`](modules/hosts/proxy) | none — headless |

The laptop, homelab and proxy outputs only exist while their `hardware.nix`
does (a `builtins.pathExists` guard in `flake.nix`), so a reinstall writes it
before the first build.

## Layout

```
flake.nix       hosts, and the input modules (disko, home-manager, lanzaboote,
                nix-flatpak, nixos-wsl, sops-nix) each one takes
modules/
  hosts/        one folder per machine: default.nix, hardware.nix, notes
  system/       base NixOS: default.nix on every host; boot/, filesystems/,
                hardening, network, zram imported per host; darwin/ for the Mac
  hardware/     gpu, peripherals, power, firmware — one concern per file
  devices/      per-device quirks, e.g. the Apple USB-C dongle's audio rules
  programs/     apps, desktop, development, games, macos, server, services, tools
  users/        the djpro and opena0 accounts
  home-manager/ home-manager wiring, and config.lib.dotfiles.link
templates/      flake templates for new projects: nix flake init -t ~/nixos#<name>
```

A program with home-manager config is a folder: `default.nix` for the system
side, `home.nix` for home-manager, and its hand-written config files beside
them. **Those config files are live** — `~/.config/<app>` is a symlink into this
checkout at `~/nixos`, so an edit applies without a rebuild, and the checkout
has to be at `~/nixos` (`/home/opena0/nixos` on the servers) or the links
dangle. [`CONVENTIONS.md`](CONVENTIONS.md) has the rest: where things go, where
docs go, how temporary workarounds expire, and checking a change.

## Install

Clone to `~/nixos` first. On a NixOS host nh isn't installed yet, so the first
switch is `sudo nixos-rebuild switch --flake ~/nixos#<host>`. The rest have their own
steps: [Mac](modules/hosts/macbook/README.md#bring-up),
[WSL](modules/hosts/wsl/README.md),
[laptop](modules/hosts/laptop/install.md),
[homelab](modules/hosts/homelab/README.md#reinstall),
[proxy](modules/hosts/proxy/README.md#install-nixos-anywhere-and-disko).

At the greeter pick **Hyprland (uwsm)**, not plain Hyprland: uwsm runs the
session as a systemd user session, so autostarted apps get units
(`systemctl --user status waybar`). If the greeter won't start, `Ctrl`+`Alt`+`F2`
reaches a text login.

After that it's nh, which knows the flake is at `~/nixos` and shows builds
through nom: `nh os switch` (NixOS) or `nh darwin switch` (Mac), and
`nh os build` to see what would change without switching. `nh clean` runs
weekly ([`programs/tools/nh`](modules/programs/tools/nh/default.nix)).

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

## Secrets

sops-nix. The desktop, homelab and proxy each have a
`modules/hosts/<host>/secrets.yaml`, listed with what uses each key in that
host's README. Every file is encrypted to both YubiKeys
([which ones](modules/hardware/peripherals/yubikey/README.md))
and to its host's SSH key, as set in [`.sops.yaml`](.sops.yaml). The YubiKeys
are for editing; a host decrypts its own file at activation with its host key.

```
sops modules/hosts/<host>/secrets.yaml     # from the repo root, YubiKey plugged in
```

- **Every key has to exist before the host builds**: sops-nix checks the file
  against what the modules declare.
- **Never put a value in a Nix string** — the store is world-readable and the
  repo public. A service reads `config.sops.secrets.<name>.path`, or a
  `sops.templates` file (an `--env-file`, a config with placeholders filled
  in). Templates a container reads at start carry `restartUnits`, so editing a
  secret restarts what uses it.
- **A host's recipient** is its SSH host key run through `ssh-to-age`. Keep the
  private key in Bitwarden: a reinstall that restores it to `/etc/ssh`
  decrypts on first boot with nothing to change. A new key means a new
  recipient:

  ```
  nix shell nixpkgs#ssh-to-age -c ssh-to-age < ssh_host_ed25519_key.pub
  # or, from a running host: ssh-keyscan -p 7456 -t ed25519 <host> | ssh-to-age
  ```

  Replace the host's entry in `.sops.yaml`, run
  `sops updatekeys modules/hosts/<host>/secrets.yaml`, and commit both.

## CI

GitHub Actions builds every host on each push to `main` and each PR, one job
per entry in the flake's `checks`: the NixOS hosts, the Mac on a macOS runner,
and alejandra's formatting check. `nom flake check` builds the Linux ones
locally.

Every Monday [`update.yml`](.github/workflows/update.yml) runs
`nix flake update`, builds every host against the new lock, and opens a
`chore: update flake.lock` PR only once all of them pass. That PR shows no
checks of its own, because a PR opened with `GITHUB_TOKEN` starts no workflows;
the update run is its check. Opening it needs *Allow GitHub Actions to create
and approve pull requests* under Settings → Actions → General.

## Docs

Why a setting is the way it is sits in a comment beside it. These are the
procedures and overviews:

| topic | where |
| --- | --- |
| Conventions: layout, style, doc rules, temporary workarounds, checking a change | [`CONVENTIONS.md`](CONVENTIONS.md) |
| Desktop: hardware, secrets, backups | [`hosts/desktop`](modules/hosts/desktop/README.md) |
| Laptop: hardware | [`hosts/laptop`](modules/hosts/laptop/README.md) |
| Laptop: the EndeavourOS → NixOS install, BitLocker, Secure Boot | [`hosts/laptop/install.md`](modules/hosts/laptop/install.md) |
| Laptop: whole-machine NVMe freezes | [`hosts/laptop/nvme-vmd-stalls.md`](modules/hosts/laptop/nvme-vmd-stalls.md) |
| MacBook: bring-up, keyboard, the bar, SSH | [`hosts/macbook`](modules/hosts/macbook/README.md) |
| Karabiner's rules | [`programs/macos/karabiner`](modules/programs/macos/karabiner/config/README.md) |
| WSL | [`hosts/wsl`](modules/hosts/wsl/README.md) |
| Homelab: services, reinstall and restore, Kanidm, Actual, bridges, backups | [`hosts/homelab`](modules/hosts/homelab/README.md) |
| Homelab: anime downloads and Jellyfin | [`programs/server/anime`](modules/programs/server/anime/README.md) |
| Proxy VPS: hosting, install, the TCP forwarder, exit node, public DNS | [`hosts/proxy`](modules/hosts/proxy/README.md) |
| YubiKeys: SSH, sops identities, troubleshooting | [`hardware/peripherals/yubikey`](modules/hardware/peripherals/yubikey/README.md) |
| Syncthing: folders, adding a device | [`programs/services/syncthing`](modules/programs/services/syncthing/README.md) |

## License

[MIT](LICENSE), except:

- [`modules/programs/development/neovim/config`](modules/programs/development/neovim/config),
  from the LazyVim starter: Apache-2.0, in [its own `LICENSE`](modules/programs/development/neovim/config/LICENSE).
- [`modules/hosts/desktop/regreet-wallpaper.jpg`](modules/hosts/desktop/regreet-wallpaper.jpg),
  from [wallhaven](https://wallhaven.cc/w/je8p85): not covered; it belongs to
  its artist.
