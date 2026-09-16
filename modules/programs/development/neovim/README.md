# Neovim

LazyVim, with the plugin specs in `config/lua/plugins/`. It is
part of the shell half, so it lands on every machine. Plugins bootstrap on first
launch at the commits pinned in `lazy-lock.json` — see the lockfile note in
[`AGENTS.md`](../../../../AGENTS.md).

## LSPs

Mason is disabled (`plugins/mason.lua`). The language servers, formatters and
linters the enabled extras call are nixpkgs packages in `lsp/`, which only the
machines used for development import — the servers get nvim without them.
Enabling a new extra means adding its tools there; `:checkhealth vim.lsp` and
`:ConformInfo` show what is missing.

## marie-lsp

One server in there is not in nixpkgs: `marie-lsp`, the language server for
MARIE assembly (`.mas`), from
[marie-rs](https://github.com/on9au/marie-rs). That repo is a flake, and
projects that use it (FIT1047) take it as an input, so their dev shell puts
`marie` and `marie-lsp` on PATH when direnv loads it. Nothing here installs it
globally.

Nothing is broken while the binary is missing. `plugins/marie.lua` prefers
`marie-lsp` on PATH (a dev shell, or `~/.cargo/bin`) and falls back to
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

