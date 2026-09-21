# Roblox

Rojo and the Luau tooling, on the three machines used for development. Studio
itself is not here — macOS runs it natively, and on Linux it is Vinegar, next to
Sober in [`programs/games/roblox.nix`](../../games/roblox.nix). This module is
the other half: the files Studio syncs from, and the editor that understands
them.

## Why the editor side is a plugin

`luau-lsp` on its own has no idea what `game.ServerScriptService.Foo` is. Two
things make it a Roblox server rather than a plain Luau one:

- a **sourcemap**, the file-to-instance mapping Rojo derives from the project
  file, which has to be regenerated as files move (`rojo sourcemap --watch`);
- **type definitions** for the Roblox globals, which track the current API dump
  and so cannot be a fixed file in this repo.

`luau-lsp.nvim` does both, which is why
[`plugins/luau.lua`](../neovim/config/lua/plugins/luau.lua) declares the server
through that plugin instead of LazyVim's `servers` table — configuring it in
both places would start two clients. The plugin is skipped entirely when
`luau-lsp` is not on PATH, so the hosts without this module still open `.luau`
files cleanly, the same way `plugins/marie.lua` handles `marie-lsp`.

## Per project

`nix flake init -t ~/nixos#rojo` writes the dev shell in
[`templates/rojo`](../../../../templates/rojo): the tools above plus `stylua`,
`lune` and `wally`, with an `.envrc` so direnv loads them. Things that belong to
a project and not to a machine live there — `wally` in particular, since a
Roblox project pins its own package versions, and nixpkgs has no darwin build
of it.

The scaffolding itself is still `rojo init`; the template only brings the
toolchain.
