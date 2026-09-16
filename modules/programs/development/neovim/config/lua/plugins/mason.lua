-- LSPs, formatters and linters come from nixpkgs
-- (programs/development/neovim/lsp/home.nix), not Mason. Without
-- mason-lspconfig, LazyVim enables every configured server directly.
return {
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
}
