-- Roblox Luau. nvim already maps .luau to the `luau` filetype, so the parser
-- below is worth installing everywhere; the server is not, see below.
local specs = {
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "luau" } } },

  -- stylua owns Luau layout, and a project's stylua.toml owns stylua. conform
  -- finds that file itself, so nothing about the style is repeated here.
  --
  -- Indentation is not set here either: a Rojo project ships an .editorconfig,
  -- which nvim reads natively, so tabs and their width follow the project
  -- rather than this config.
  --
  -- stylua is a per-project tool (templates/rojo), not one of the binaries in
  -- programs/development/roblox, so this only formats inside a project's
  -- direnv shell. That is the only place .luau files live.
  {
    "stevearc/conform.nvim",
    opts = {
      -- luau-lsp does not format, so LazyVim's LSP fallback is a no-op today.
      -- Saying "never" keeps it that way if it ever gains one.
      formatters_by_ft = { luau = { "stylua", lsp_format = "never" } },
    },
  },
}

-- luau-lsp on its own knows nothing about the DataModel: the instance tree
-- comes from a sourcemap Rojo regenerates as files move, and the Roblox globals
-- come from type definitions that track the current API dump. luau-lsp.nvim
-- owns both -- it runs `rojo sourcemap --watch` and fetches the definitions --
-- which is why the server is declared here and not in LazyVim's lspconfig
-- `servers` table. Enabling it there too would start a second client.
--
-- Only the machines importing programs/development/roblox have the binaries, so
-- elsewhere this half is left out, the same as plugins/marie.lua.
if vim.fn.executable("luau-lsp") == 1 then
  table.insert(specs, {
    "lopi-py/luau-lsp.nvim",
    ft = "luau",
    opts = {
      platform = { type = "roblox" },
      -- Written to sourcemap.json in the project root; the template gitignores it.
      sourcemap = { enabled = true, autogenerate = true },
      -- Studio plugins see more of the API than a game script does. The stricter
      -- level is RobloxScriptSecurity; PluginSecurity is what a plugin may call.
      types = { roblox_security_level = "PluginSecurity" },
    },
  })
end

return specs
