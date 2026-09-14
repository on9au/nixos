-- Keyboard and cursor. The pointing devices differ per machine -- a touchpad
-- and a dock-attached mouse on one, a wireless mouse on the other -- so those
-- are in the host file:
--
--   hosts/LAPTOP-ON9AU/input.lua   touchpad, plus the mouse in the dock
--   hosts/desktop/input.lua        mouse feel
--
-- List what libinput actually found with:  hyprctl devices

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        -- 0 = use libinput's own acceleration untouched. Per-device overrides
        -- go in the host file rather than here.
        sensitivity = 0,

        -- Snappier key repeat than the default 25/600.
        repeat_rate  = 40,
        repeat_delay = 250,
    },

    cursor = {
        -- Hide the pointer after 5s of no mouse movement.
        inactive_timeout = 5,
    },

    binds = {
        -- Pressing the current workspace's key again jumps back to the
        -- previous one.
        workspace_back_and_forth = true,
    },
})

-- numlock_by_default is set per host: the desktop has a numpad, the laptop
-- does not.
require("host").load("input")
