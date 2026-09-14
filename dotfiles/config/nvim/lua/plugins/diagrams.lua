-- Mermaid (and d2/plantuml/gnuplot) diagrams rendered inline in markdown, and
-- in standalone .mmd files.
--
-- diagram.nvim shells out to `mmdc` (mermaid-cli) to turn a diagram
-- source into a PNG, then hands the PNG to image.nvim, which draws it with the
-- kitty graphics protocol. Requires kitty (or another graphics-capable term) and
-- ImageMagick; inside tmux it also needs `allow-passthrough on`, which
-- tmux.conf already sets.

-- Standalone diagram files aren't a filetype nvim knows about.
vim.filetype.add({
  extension = {
    mmd = "mermaid",
    mermaid = "mermaid",
  },
})

-- mmdc reads this for the catppuccin-mocha palette; keep in sync with the
-- colorscheme in plugins/catppuccin.lua.
local mermaid_config = vim.fn.expand("~/.config/mermaid/config.json")

local diagram_fts = { "markdown", "markdown.mdx", "norg", "mermaid" }

-- diagram.nvim only ships markdown and neorg integrations, both of which look
-- for fenced blocks. A .mmd file *is* the block, so it needs its own.
local function mermaid_file_integration()
  return {
    id = "mermaid-file",
    filetypes = { "mermaid" },
    renderers = { require("diagram/renderers").mermaid },
    ---@param bufnr number
    query_buffer_diagrams = function(bufnr)
      bufnr = bufnr or vim.api.nvim_get_current_buf()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local source = table.concat(lines, "\n")
      -- mmdc errors out on an empty diagram, which a new file always is.
      if vim.trim(source) == "" then
        return {}
      end

      -- Anchored on the last line: the image is drawn one row below its anchor
      -- (render_offset_top), so it lands under the source instead of over it.
      local last = math.max(#lines - 1, 0)
      return {
        {
          bufnr = bufnr,
          renderer_id = "mermaid",
          source = source,
          range = { start_row = last, start_col = 0, end_row = last, end_col = 0 },
        },
      }
    end,
  }
end

-- Open the diagram under the cursor in its own tab, at full size.
local function diagram_hover()
  local diagram = require("diagram")
  if vim.bo.filetype ~= "mermaid" then
    return diagram.show_diagram_hover()
  end

  -- In a .mmd file the whole buffer is one diagram anchored on its last line,
  -- and the hover only matches diagrams whose range covers the cursor. Aim at
  -- the anchor so it works from anywhere in the file; hover_at_cursor picks the
  -- diagram up synchronously, so the cursor can go back right after.
  local win = vim.api.nvim_get_current_win()
  local pos = vim.api.nvim_win_get_cursor(win)
  vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(0), 0 })
  local ok, err = pcall(diagram.show_diagram_hover)
  pcall(vim.api.nvim_win_set_cursor, win, pos)
  if not ok then
    error(err)
  end
end

return {
  {
    "3rd/image.nvim",
    -- No build step: the default magick_cli processor shells out to ImageMagick
    -- instead of needing the `magick` luarock (magick_rock).
    build = false,
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      integrations = {
        -- diagram.nvim drives the diagram rendering; this is for plain image
        -- links (![](foo.png)) in markdown.
        markdown = {
          enabled = true,
          clear_in_insert_mode = true,
          only_render_image_at_cursor = false,
        },
      },
      max_width_window_percentage = 80,
      max_height_window_percentage = 50,
      -- Images are drawn over the terminal grid, so they survive splits/floats
      -- that should be covering them unless we clear on overlap.
      window_overlap_clear_enabled = true,
      editor_only_render_when_focused = true,
      tmux_show_only_in_active_window = true,
    },
  },
  {
    "3rd/diagram.nvim",
    dependencies = { "3rd/image.nvim" },
    ft = diagram_fts,
    -- A function so the requires below run once the plugin is on the rtp.
    opts = function()
      local integrations = require("diagram/integrations")

      return {
        events = {
          -- No TextChanged: every change that isn't already cached spawns an
          -- mmdc (chromium) render, which is far too eager while writing a
          -- whole file of mermaid. Saving or leaving insert mode is enough.
          render_buffer = { "InsertLeave", "BufWinEnter", "BufWritePost" },
          clear_buffer = { "BufLeave" },
        },
        -- Replaces the defaults wholesale, so the built-ins come along too.
        integrations = {
          integrations.markdown,
          integrations.neorg,
          mermaid_file_integration(),
        },
        renderer_options = {
          mermaid = {
            -- theme is left unset on purpose: -t would override the "base"
            -- theme the config file selects, discarding the palette under it.
            background = "transparent",
            scale = 3, -- render above 1x so the downscaled image stays sharp
            cli_args = vim.fn.filereadable(mermaid_config) == 1 and { "-c", mermaid_config } or nil,
          },
        },
      }
    end,
    keys = {
      { "<leader>md", diagram_hover, desc = "Diagram at cursor (tab)", ft = diagram_fts },
      {
        "<leader>mr",
        function()
          require("diagram").render()
        end,
        desc = "Re-render diagrams",
        ft = diagram_fts,
      },
      {
        "<leader>mc",
        function()
          require("diagram").clear()
        end,
        desc = "Clear diagrams",
        ft = diagram_fts,
      },
    },
  },
  -- Syntax highlighting for the fenced blocks and for standalone .mmd files.
  -- The rest are what `:checkhealth snacks` flags as missing for its doc
  -- image rendering (Snacks.image.doc): without them, math/code blocks in
  -- those languages don't get image-rendered even though mmdc/tectonic are
  -- both installed and working. Not "norg" -- nvim-treesitter has no parser
  -- registered under that name (it's neorg's own ecosystem, and neorg isn't
  -- a plugin here), so it can only ever warn/skip, never actually install.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "mermaid", "css", "latex", "scss", "svelte", "typst", "vue" },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>m", group = "mermaid/diagram", icon = "󰙅 " },
      },
    },
  },
}
