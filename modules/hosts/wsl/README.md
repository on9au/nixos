# G3JC7G4 (WSL)

Work laptop via WSL

Specs [in the laptop README](../laptop/README.md)

NixOS-WSL on a Windows work laptop (`G3JC7G4`). Only the shell half lands:
zsh, tmux, nvim, and the tools they shell out to — `default.nix` imports
only the shell and development modules. No compositor, because the desktop over
here *is* Windows.

## node, and the Windows PATH

WSL appends the whole Windows `PATH` to the Linux one. That is usually
harmless — Linux binaries come first — but it is not harmless for anything
missing on the Linux side: with no node installed here, `npm` and `pnpm`
resolved to

```
/mnt/c/Users/…/AppData/Local/fnm_multishells/…/npm
```

which is Windows node running under a Linux shell. It cannot build native
modules for this filesystem, and it is what Mason would have used to install
nvim's LSP servers.

The fix is to have a Linux node: `nodejs` is in `programs/development/toolchain`, so
there always is one, with fnm on top for per-project versions.

That covers `node`, `npm`, `npx` and `corepack`, which all ship inside `nodejs`
— but not `pnpm`, which does not, and so went on resolving to the Windows
`pnpm.exe` long after node was installed here. It is listed as its own package
in the same module. Corepack is no way out of this: `corepack enable` writes
its shims next to the `node` binary, which is a store path, so it fails with
`EROFS: read-only file system`.

## The user manager at boot

`user@1000.service` (started early because the user lingers) regularly fails
at WSL boot with `Failed to spawn executor: Device or resource busy`. Nothing
retries it, so the session has no `/run/user/1000/bus`, `systemctl --user`
fails, and `nh os switch` ends with

```
Error: Failed to open dbus connection
Unable to autolaunch a dbus-daemon without a $DISPLAY for X11
warning: user activation for djpro failed
```

`default.nix` gives `user@` a `Restart=on-failure`. If it has already failed
this boot, `sudo systemctl start user@1000.service` brings it up by hand.

## Monash git credentials

The desktop stores the `git.infotech.monash.edu` PAT with
`git-credential-libsecret` in gnome-keyring (`programs/services/keyring`),
which PAM unlocks at a graphical login that never happens here. So this host
points that remote at Git for Windows' Credential Manager instead
(`/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe`). The PAT
lands in Windows Credential Manager, which Windows unlocks when you log in, so
git asks for it once.
`provider = generic` skips GCM's OAuth detection and asks plainly for a
username and PAT. This depends on Git for Windows being installed.

## Skipped on purpose

`imagemagick`, `ghostscript`, `tectonic` and `mermaid-cli` are not installed
here (`programs/development/neovim/images` is not imported). They exist to render Snacks.image and `plugins/diagrams.lua` output
inline, which needs a terminal that speaks the kitty graphics protocol — and
the terminal for this VM is on the Windows side, which does not. image.nvim
draws nothing without that protocol, so the rendering chain behind it has
nothing to hand its output to; `plugins/diagrams.lua` has no `executable()`
guard, so if a diagram buffer does start complaining about a missing `mmdc`,
install that group by hand rather than expecting it to degrade quietly.

`wl-clipboard` *is* installed, despite the name. WSLg puts a Wayland socket in
every WSL session, so `wl-copy`/`wl-paste` work, and the clipboard stops
depending on a `win32yank.exe` that only exists because Neovim happens to be
installed on the Windows side as well.

## Not applicable

The desktop modules are bare-metal concerns and are not imported:
greetd (no login manager — WSL starts the shell directly), the lid switch, and
gnome-keyring, whose whole design here is an unlock driven by PAM at a
graphical login that never happens.
