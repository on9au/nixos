# G3JC7G4 (WSL)

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

The fix is just to have a Linux node: `nodejs` is in `programs/development/toolchain`, so
there always is one, with fnm on top for per-project versions.

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
