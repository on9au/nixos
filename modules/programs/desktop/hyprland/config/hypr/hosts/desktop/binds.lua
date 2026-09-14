-- Keys that only make sense on the two-screen desktop.
--
-- Same modifier as the shared binds.lua; declared again because this file is
-- required rather than included, and one constant is cheaper than passing it.
local mod = "SUPER"

--------------------
---- MONITORS   ----
--------------------

-- comma = left screen (AOC), period = right screen (Dell).
--
-- These are the whole reason this file exists: on a single-output machine they
-- are dead binds that swallow two comfortable keys.
hl.bind(mod .. " + comma",          hl.dsp.focus({ monitor = "DP-2" }),       { desc = "focus left monitor" })
hl.bind(mod .. " + period",         hl.dsp.focus({ monitor = "DP-1" }),       { desc = "focus right monitor" })
hl.bind(mod .. " + SHIFT + comma",  hl.dsp.window.move({ monitor = "DP-2" }), { desc = "window to left monitor" })
hl.bind(mod .. " + SHIFT + period", hl.dsp.window.move({ monitor = "DP-1" }), { desc = "window to right monitor" })

-- No backlight binds here: desktop monitors have no software backlight, and
-- the keyboard has no XF86KbdBrightness keys. See the laptop's binds.lua.
