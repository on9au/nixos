-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Disable the legacy RPC-hosted remote-plugin providers. They're for vim
-- plugins written IN perl/ruby/node/python that talk to nvim over RPC --
-- nothing in this config is one (everything here is a pure Lua plugin), so
-- there's no host to ever start, and :checkhealth just flags each one as
-- "package not installed" for a package nothing would use.
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0
