-- Window and workspace rules.
--
-- Find the class/title of a window to match on with:
--   hyprctl clients | grep -E 'class|title'

local apps = require("apps")

-------------------------
---- WORKSPACE RULES ----
-------------------------

-- How many workspaces are persistent, and which screen each one lives on,
-- depends on how many screens there are -- so it is per-host:
--
--   hosts/LAPTOP-ON9AU/rules.lua   1-5 persistent, no pinning (one output)
--   hosts/desktop/rules.lua        1-10 persistent, pinned across two screens
require("host").load("rules")

----------------------
---- WINDOW RULES ----
----------------------

-- Ignore maximize requests from apps; let the tiler decide.
hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- Fixes drag-and-drop from XWayland apps. Kept from Hyprland's defaults.
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Dialogs, pickers and settings windows are more usable floating and centred
-- than tiled into a quarter of a 4K screen.
hl.window_rule({
    name   = "float-dialogs",
    match  = { title = "^(Open File|Open Folder|Save As|Save File|Select a File|Choose Files|Open|Print)( .*)?$" },
    float  = true,
    center = true,
    size   = "1100 750",
})

hl.window_rule({
    name   = "float-utilities",
    match  = { class = "^(pavucontrol|nm-connection-editor|blueman-manager|org.kde.polkit-kde-authentication-agent-1|hyprpolkitagent)$" },
    float  = true,
    center = true,
})

-- Picture-in-picture: small, floating, and kept on top across workspaces.
hl.window_rule({
    name  = "picture-in-picture",
    match = { title = "^(Picture[- ]in[- ][Pp]icture)$" },
    float = true,
    pin   = true,
    size  = "640 360",
    move  = "monitor_w-680 monitor_h-400",
})

-- Steam's little popups tile badly. Listed explicitly rather than using a
-- negative lookahead, which the RE2 engine Hyprland matches with rejects.
hl.window_rule({
    name  = "float-steam-popups",
    match = { class = "^steam$", title = "^(Friends List|Steam Settings|Special Offers|.*Chat.*)$" },
    float = true,
})

-- Screen-sharing indicators and similar overlays should never steal focus.
hl.window_rule({
    name             = "no-focus-overlays",
    match            = { class = "^(xdg-desktop-portal-hyprland)$" },
    no_initial_focus = true,
})

---------------------
---- LAYER RULES ----
---------------------

-- Blur the bar, the launcher and the notification centre so they sit on the
-- wallpaper nicely instead of looking pasted on.
hl.layer_rule({
    name          = "blur-shell",
    match         = { namespace = "^(waybar|swaync-control-center|swaync-notification-window|launcher)$" },
    blur          = true,
    ignore_alpha  = 0.2,
})
