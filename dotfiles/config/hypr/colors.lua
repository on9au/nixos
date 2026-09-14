-- Catppuccin Mocha.
-- Matches the kitty theme in ~/.config/kitty/current-theme.conf and the
-- waybar / fuzzel / swaync stylesheets, so the whole desktop stays in sync.
--
-- Hex values are plain strings; use rgba()/rgb() helpers below when a
-- Hyprland option wants a colour literal.
--
-- Upstream palette: https://github.com/catppuccin/catppuccin

local M = {}

M.hex = {
    rosewater = "f5e0dc",
    flamingo  = "f2cdcd",
    pink      = "f5c2e7",
    mauve     = "cba6f7",
    red       = "f38ba8",
    maroon    = "eba0ac",
    peach     = "fab387",
    yellow    = "f9e2af",
    green     = "a6e3a1",
    teal      = "94e2d5",
    sky       = "89dceb",
    sapphire  = "74c7ec",
    blue      = "89b4fa",
    lavender  = "b4befe",

    text      = "cdd6f4",
    subtext1  = "bac2de",
    subtext0  = "a6adc8",
    overlay2  = "9399b2",
    overlay1  = "7f849c",
    overlay0  = "6c7086",
    surface2  = "585b70",
    surface1  = "45475a",
    surface0  = "313244",
    base      = "1e1e2e",
    mantle    = "181825",
    crust     = "11111b",
}

--- Opaque colour literal, e.g. rgb("mauve") -> "rgb(cba6f7)"
---@param name string key in M.hex
---@return string
function M.rgb(name)
    return ("rgb(%s)"):format(M.hex[name])
end

--- Colour literal with alpha, e.g. rgba("base", "cc") -> "rgba(1e1e2ecc)"
---@param name string key in M.hex
---@param alpha string two hex digits, "00" transparent .. "ff" opaque
---@return string
function M.rgba(name, alpha)
    return ("rgba(%s%s)"):format(M.hex[name], alpha)
end

return M
