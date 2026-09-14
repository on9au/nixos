-- Applications started with the session -- the two-screen desktop.
--
-- The daemons are in autostart.lua; this file is only the applications.
-- Discord and Spotify sit on 6 and 7, which are the Dell's workspaces.

local apps   = require("apps")
local launch = require("launch")

launch.app_on(apps.terminal, 1)
launch.app_on(apps.browser, 2)
launch.app_on("discord", 6)
launch.app_on(apps.music, 7)

-- Steam to the tray only. -silent is Steam's own flag for starting without
-- opening the library window, so there is no window to place.
launch.app("steam -silent")
