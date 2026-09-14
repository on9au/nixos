-- Applications started with the session -- LAPTOP-ON9AU.
--
-- The daemons (waybar, swaync, hypridle, the polkit agent, cliphist, the
-- wallpaper) are not here; they are the same on every machine and live in
-- autostart.lua. This file is only the applications.
--
-- Required from inside the hyprland.start handler, so these run at start-up
-- like the daemons above them.

local apps   = require("apps")
local launch = require("launch")

launch.app_on(apps.terminal, 1)
launch.app_on(apps.browser, 2)

-- Spotify sits on 5, the last of the persistent workspaces: out of the way of
-- the terminal and the browser, but one key away and visible in the bar.
--
-- Not moved to the panel now that 6-10 live there (rules.lua). All three of
-- these want to be somewhere that exists undocked as well as docked, and
-- workspaces 1-5 fall back to the panel on their own when the ultrawide is not
-- plugged in -- whereas anything parked on 6-10 would vanish under the lid in
-- clamshell.
launch.app_on(apps.music, 5)

-- Not started here, and deliberately:
--
--   discord   was on workspace 6, which no longer exists as its own screen.
--             Start it by hand when it is wanted.
--   steam     is not installed on this machine. Leaving `steam -silent` in
--             would fail at every single login.
