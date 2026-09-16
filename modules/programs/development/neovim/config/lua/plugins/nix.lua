-- lang.nix formats with nixfmt; this repo is formatted with alejandra.
return {
  {
    "stevearc/conform.nvim",
    opts = { formatters_by_ft = { nix = { "alejandra" } } },
  },
}
