-- Which machine this is, from the hostname.
--
-- Everything that genuinely differs between machines lives in hosts/<host>/,
-- one file per topic, and the generic file for that topic pulls it in through
-- host.load():
--
--   monitors.lua   -> hosts/<host>/monitors.lua    outputs, modes, scale
--   input.lua      -> hosts/<host>/input.lua       pointing devices
--   binds.lua      -> hosts/<host>/binds.lua       hardware-specific keys
--   rules.lua      -> hosts/<host>/rules.lua       workspace layout
--   apps.lua       -> hosts/<host>/apps.lua        wallpaper
--   autostart.lua  -> hosts/<host>/autostart.lua   which applications start
--
-- Everything else -- keybindings, window rules, look and feel, environment --
-- is shared, and should stay that way. Only add a host file when the two
-- machines actually disagree.
--
-- Adding a machine: copy a hosts/ directory and add it to `dirs` below. A
-- hostname with no entry falls through to `desktop`.
--
-- host.load() is a plain require, so a typo or a syntax error in a host file
-- is a loud error rather than a silent fallback to another machine's monitor
-- layout.

local M = {}

local dirs = {
    ["LAPTOP-ON9AU"] = "hosts.LAPTOP-ON9AU",
}

local f = io.open("/proc/sys/kernel/hostname")
M.name = f and f:read("*l") or ""
if f then f:close() end

M.dir = dirs[M.name] or "hosts.desktop"

---Load one topic file from this machine's host directory.
---@param topic string
function M.load(topic)
    return require(M.dir .. "." .. topic)
end

return M
