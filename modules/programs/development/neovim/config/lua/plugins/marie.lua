-- MARIE assembly (.mas/.mar), the toy architecture from the Null/Lobur book,
-- served by `marie-lsp` out of ~/Projects/marie-rs.
--
-- The upstream drop-in (editors/nvim/marie.lua in that repo) is written for a
-- bare Neovim: it calls vim.lsp.config/enable itself and then hand-rolls
-- LspAttach keymaps and inlay hints. LazyVim already does the last two for
-- every client that attaches -- servers["*"].keys covers gd/gr/K/<leader>ca/
-- <leader>cr, and its inlay_hints.enabled hook fires on any server advertising
-- textDocument/inlayHint -- so all that is left here is the server itself,
-- declared the way every other server in this config is.

-- Nothing knows what a .mas file is, so teach it first. This half is worth
-- doing even where the server is missing -- it is what makes the buffer say
-- `marie` rather than nothing at all.
vim.filetype.add({ extension = { mas = "marie", mar = "marie" } })

-- `cargo install --path crates/bin/marie-lsp` lands in ~/.cargo/bin, which
-- the toolchain module puts on PATH. Fall back to a release build inside the checkout,
-- which is the version you want while working on the server itself and not
-- reinstalling after every change.
local server = "marie-lsp"
if vim.fn.executable(server) == 0 then
  server = vim.fn.expand("~/Projects/marie-rs/target/release/marie-lsp")
end

-- Four targets share this nvim config and only the ones with the checkout have
-- the binary. Registering the server anyway would turn every .mas file opened
-- on the others into a spawn error, so hand lazy.nvim an empty spec instead --
-- the filetype above still stands.
if vim.fn.executable(server) == 0 then
  return {}
end

return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      marie = {
        cmd = { server },
        filetypes = { "marie" },
        -- MARIE programs are single files, so there is no project root to
        -- speak of; .git keeps one client per checkout and otherwise the
        -- file's own directory is used.
        root_markers = { ".git" },
      },
    },
  },
}
