# G3JC7G4 (WSL)

NixOS-WSL on the [laptop](../laptop/README.md)'s Windows install. Only the
shell half lands: zsh, tmux, nvim and the development toolchain. The desktop
here *is* Windows, so there is no compositor and no gnome-keyring, and the
neovim image modules are left out because the terminal is on the Windows side.

Git for Windows has to be installed: the Monash remote's credentials go
through its Credential Manager (`default.nix`).

## When `nh os switch` can't reach the user bus

```
Error: Failed to open dbus connection
warning: user activation for djpro failed
```

`user@1000.service` lost its race at WSL boot. `default.nix` restarts it on
failure; if it has already given up this boot,
`sudo systemctl start user@1000.service`.
