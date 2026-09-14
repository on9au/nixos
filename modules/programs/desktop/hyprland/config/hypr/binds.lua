-- Keybindings.
--
-- Heads up: these follow the i3/sway convention rather than Hyprland's
-- shipped defaults, because that is what most guides and muscle memory
-- assume. The two that differ from the shipped hyprland.lua:
--
--   SUPER + Return   terminal   (Hyprland's default puts this on SUPER + Q)
--   SUPER + Q        close      (Hyprland's default puts this on SUPER + C)
--
-- List every active bind at runtime with:  hyprctl binds

local apps = require("apps")

local mod = "SUPER"

-- Vim directions alongside the arrow keys, since hjkl is already muscle
-- memory from nvim + tmux.
local directions = {
    { key = "left",  dir = "l", vim = "H" },
    { key = "right", dir = "r", vim = "L" },
    { key = "up",    dir = "u", vim = "K" },
    { key = "down",  dir = "d", vim = "J" },
}

--------------------
---- LAUNCHING  ----
--------------------

hl.bind(mod .. " + Return", hl.dsp.exec_cmd(apps.terminal),     { desc = "terminal" })
hl.bind(mod .. " + E",      hl.dsp.exec_cmd(apps.file_manager), { desc = "file manager" })
hl.bind(mod .. " + B",      hl.dsp.exec_cmd(apps.browser),      { desc = "browser" })

-- Launcher on ALT + Space. Deliberately not SUPER + Space: that is fcitx5's
-- input-method toggle (see ~/.config/fcitx5/config, [Hotkey/TriggerKeys]).
hl.bind("ALT + space", hl.dsp.exec_cmd(apps.launcher), { desc = "app launcher" })

-- Clipboard history: cliphist stores every copy, fuzzel picks one.
hl.bind(mod .. " + SHIFT + V",
    hl.dsp.exec_cmd([[sh -c 'cliphist list | fuzzel --dmenu | cliphist decode | wl-copy']]),
    { desc = "clipboard history" })

-- Emoji picker: bemoji, drawn with fuzzel, copies and types the pick.
--
-- Not on SUPER + period, which is the obvious key for it and is what most
-- desktops use: the desktop host spends comma/period on focus-a-monitor
-- (hosts/desktop/binds.lua), so it would work on the laptop and be dead here.
-- Shift + E instead, next to the file manager on E.
--
-- Absolute path because ~/.local/bin is not on PATH here.
hl.bind(mod .. " + SHIFT + E",
    hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/emoji"),
    { desc = "emoji picker" })

-- Notification centre.
hl.bind(mod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"), { desc = "notifications" })

------------------
---- SESSION  ----
------------------

-- Goes through logind so hypridle also learns the session locked.
-- On Escape rather than the usual SUPER + L because L is taken by hjkl
-- window focus below.
hl.bind(mod .. " + Escape", hl.dsp.exec_cmd("loginctl lock-session"), { desc = "lock screen" })

-- Power menu: lock / log out / suspend / reboot / shut down.
--
-- Not a bare exit dispatcher: under uwsm the session is a systemd unit, and
-- quitting the compositor directly leaves the rest of the user session units
-- running. The script uses `uwsm stop` for that reason.
--
-- Absolute path because ~/.local/bin is not on PATH here.
hl.bind(mod .. " + SHIFT + M",
    hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/powermenu"),
    { desc = "power menu" })

-------------------
---- WINDOWS   ----
-------------------

hl.bind(mod .. " + Q",         hl.dsp.window.close(),                            { desc = "close window" })
hl.bind(mod .. " + V",         hl.dsp.window.float({ action = "toggle" }),       { desc = "toggle floating" })
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen" }), { desc = "fullscreen" })
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }),  { desc = "maximize" })
hl.bind(mod .. " + G",         hl.dsp.window.center(),                           { desc = "centre floating window" })
hl.bind(mod .. " + SHIFT + P", hl.dsp.window.pin(),                              { desc = "pin above workspaces" })
hl.bind(mod .. " + P",         hl.dsp.window.pseudo(),                           { desc = "pseudo-tile (dwindle)" })
-- On T, not Hyprland's default J, which hjkl focus claims below.
hl.bind(mod .. " + T",         hl.dsp.layout("togglesplit"),                     { desc = "flip split direction" })

-- Focus, move and resize in all four directions, on both arrows and hjkl.
for _, d in ipairs(directions) do
    for _, key in ipairs({ d.key, d.vim }) do
        hl.bind(mod .. " + " .. key,
            hl.dsp.focus({ direction = d.dir }),
            { desc = "focus " .. d.dir })

        hl.bind(mod .. " + SHIFT + " .. key,
            hl.dsp.window.move({ direction = d.dir }),
            { desc = "move window " .. d.dir })
    end
end

-- Resize in 60px steps (logical pixels, so it feels the same on both screens).
local resize_step = 60
local resize_deltas = {
    { key = "left",  vim = "H", x = -resize_step, y = 0 },
    { key = "right", vim = "L", x = resize_step,  y = 0 },
    { key = "up",    vim = "K", x = 0,            y = -resize_step },
    { key = "down",  vim = "J", x = 0,            y = resize_step },
}

for _, r in ipairs(resize_deltas) do
    for _, key in ipairs({ r.key, r.vim }) do
        hl.bind(mod .. " + CTRL + " .. key,
            hl.dsp.window.resize({ x = r.x, y = r.y, relative = true }),
            { desc = "resize window", repeating = true })
    end
end

-- Drag to move / resize with the mouse.
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

----------------------
---- WORKSPACES    ----
----------------------

-- SUPER + 1..0 focuses, SUPER + SHIFT + 1..0 throws the window there.
-- All ten exist on every machine; which of them are persistent, and which
-- screen they live on, is per-host (see rules.lua).
for i = 1, 10 do
    local key = i % 10 -- workspace 10 sits on the 0 key

    hl.bind(mod .. " + " .. key,
        hl.dsp.focus({ workspace = i }),
        { desc = "workspace " .. i })

    hl.bind(mod .. " + SHIFT + " .. key,
        hl.dsp.window.move({ workspace = i }),
        { desc = "move to workspace " .. i })
end

-- Scratchpad: a workspace that floats over whatever you are doing.
hl.bind(mod .. " + S",         hl.dsp.workspace.toggle_special("magic"),          { desc = "toggle scratchpad" })
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }), { desc = "move to scratchpad" })

-- Scroll the mouse wheel over any empty space to change workspace.
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-----------------------
---- SCREENSHOTS   ----
-----------------------

-- Saved to apps.screenshot_dir and copied to the clipboard.
-- -z freezes the screen while you drag, so hover menus stay put.
local shot = "hyprshot -z -o " .. ("%q"):format(apps.screenshot_dir) .. " -m "

hl.bind("Print",           hl.dsp.exec_cmd(shot .. "region"), { desc = "screenshot region" })
hl.bind("SHIFT + Print",   hl.dsp.exec_cmd(shot .. "output"), { desc = "screenshot monitor" })
hl.bind("ALT + Print",     hl.dsp.exec_cmd(shot .. "window"), { desc = "screenshot window" })

-----------------------
---- COLOUR PICKER ----
-----------------------

-- hyprpicker freezes the screen, gives you a zoom lens, and prints the pixel
-- you click. The script around it puts that on the clipboard -- and so into
-- cliphist, so picks come back under SUPER + Shift + V -- and shows a swatch.
--
-- C is free because close moved to Q (see the header): upstream Hyprland
-- spends it on close, i3/sway convention does not.
--
-- Absolute path because ~/.local/bin is not on PATH here.
local colorpicker = os.getenv("HOME") .. "/.local/bin/colorpicker"

hl.bind(mod .. " + C",         hl.dsp.exec_cmd(colorpicker),           { desc = "pick colour (hex)" })
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd(colorpicker .. " rgb"), { desc = "pick colour (rgb)" })

-----------------
---- MEDIA   ----
-----------------

-- `locked` keeps these working while hyprlock is up.
local media = { locked = true, repeating = true }

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), media)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      media)
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

--------------------------
---- PER-MACHINE KEYS  ----
--------------------------

-- Hardware that only one machine has: the laptop's screen and keyboard
-- backlight keys, the desktop's focus-a-monitor binds.
require("host").load("binds")
