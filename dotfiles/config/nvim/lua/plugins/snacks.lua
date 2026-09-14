local keys = {}

-- zero-pad every digit run so numeric segments compare correctly
local function natkey(s)
  s = s or ""
  local k = keys[s]
  if not k then
    k = s:gsub("%d+", function(n)
      return ("0"):rep(20 - #n) .. n
    end)
    keys[s] = k
  end
  return k
end

return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          ---@param a snacks.picker.Item
          ---@param b snacks.picker.Item
          sort = function(a, b)
            return natkey(a.sort) < natkey(b.sort)
          end,
        },
      },
    },
    image = {
      enabled = true,
      doc = {
        enabled = true,
        inline = true, -- render in-buffer; needs unicode placeholders
        float = true, -- fallback when inline is off/unsupported
        max_width = 60,
        max_height = 30,
      },
      math = { enabled = true },
    },
  },
}
