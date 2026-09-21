-- Roblox Luau. nvim already maps .luau to the `luau` filetype, so the parser
-- below is worth installing everywhere; the server is not, see below.
local specs = {
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "luau" } } },
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
