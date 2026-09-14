-- Monitors.
--
-- Outputs, modes, scaling and placement are entirely per-machine, so the whole
-- of this topic lives in the host file. See host.lua for how one is picked.
--
--   hosts/LAPTOP-ON9AU/monitors.lua   one 16" 3840x2400 panel
--   hosts/desktop/monitors.lua        AOC 32" + Dell 27"
--
-- To identify outputs after a cable change:  hyprctl monitors all

require("host").load("monitors")
