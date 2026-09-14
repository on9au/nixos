-- Things started with the session.
--
-- The daemons below run on every machine. Which *applications* start, and on
-- which workspace, is per-machine and lives in the host file:
--
--   hosts/LAPTOP-ON9AU/autostart.lua
--   hosts/desktop/autostart.lua
--
-- The launch helpers both files use are in launch.lua, which explains why
-- everything goes through `uwsm app`.

local apps   = require("apps")
local host   = require("host")
local launch = require("launch")

hl.on("hyprland.start", function()
    -- Authentication dialogs (anything asking for a password / sudo prompt).
    --
    -- Started as a unit, not by path. The binary lives in libexec, and every
    -- distribution puts libexec somewhere different -- this used to name
    -- /usr/lib/hyprpolkitagent/hyprpolkitagent, which is an Arch path and
    -- exists nowhere else, so on any other machine the agent silently never
    -- came up and every polkit prompt in the session went unanswered. The
    -- unit name is the same everywhere; upstream's own instruction is
    -- `systemctl --user start hyprpolkitagent` from the compositor autostart.
    --
    -- Safe where something else already starts it: under home-manager's
    -- services.hyprpolkitagent the unit is WantedBy the session target and is
    -- already running by the time this fires, and starting a running unit is
    -- a no-op rather than a second agent.
    launch.unit("hyprpolkitagent")

    -- Status bar and notification daemon.
    launch.app("waybar")
    launch.app("swaync")

    -- Idle handling: dim, lock, then blank the screen. Don't also enable
    -- NixOS's services.hypridle; that runs a second copy.
    launch.app("hypridle")

    -- Clipboard history, fed to the SUPER + SHIFT + V picker. Two watchers,
    -- because text and images are stored separately.
    launch.app("wl-paste --type text --watch cliphist store")
    launch.app("wl-paste --type image --watch cliphist store")

    -- Wallpaper. The daemon has to be up before an image can be handed to it,
    -- so the two are chained in one shell command rather than raced.
    hl.exec_cmd(
        ("sh -c 'awww-daemon & until awww query >/dev/null 2>&1; do sleep 0.1; done; awww img %q'")
            :format(apps.wallpaper)
    )

    ------------------------
    ---- APPLICATIONS   ----
    ------------------------
    --
    -- These used to be XDG autostart entries in ~/.config/autostart from the
    -- KDE days. Those are removed in hyprland/home.nix -- left in place they
    -- run a second copy, since uwsm honours XDG autostart too.
    --
    -- required here rather than at the top of the file so that the launches
    -- inside it happen at start-up, alongside the daemons above.
    host.load("autostart")
end)
