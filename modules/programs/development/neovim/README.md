# Neovim

LazyVim, with the plugin specs in `config/lua/plugins/`. It is
part of the shell half, so it lands on every machine. Plugins bootstrap on first
launch at the commits pinned in `lazy-lock.json` — see the lockfile note in
[`AGENTS.md`](../../../../AGENTS.md).

## marie-lsp

One server in there is not a package anywhere: `marie-lsp`, the language
server for MARIE assembly (`.mas`), built out of a local Rust workspace.

```bash
git clone https://github.com/on9au/marie-rs ~/Projects/marie-rs
cargo install --path ~/Projects/marie-rs/crates/bin/marie-lsp
```

Nothing here runs that for you, and nothing installs rustup.

Nothing is broken while the binary is missing. `plugins/marie.lua` prefers
`marie-lsp` on PATH (`~/.cargo/bin`, exported in `.zshenv`) and falls back to
`target/release/marie-lsp` in the checkout — the build you want while working
on the server itself — and where neither exists it resolves to an empty spec,
so a `.mas` file on the MacBook opens as a plain `marie` buffer rather than a
spawn error.

The upstream repo ships its own [nvim
drop-in](https://github.com/on9au/marie-rs/tree/main/editors/nvim) for a bare
Neovim, which starts the server itself and then hand-rolls LspAttach keymaps
and inlay hints. Both of those are things LazyVim already does for any client
that attaches, so the copy here keeps only the filetype and the server,
declared through `nvim-lspconfig`'s `opts.servers` like everything else.

