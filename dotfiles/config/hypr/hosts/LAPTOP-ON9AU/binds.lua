-- Hardware keys that only exist on LAPTOP-ON9AU, plus the lid switch.
--
-- Nothing here uses SUPER: these are the dedicated Fn-row keys, which the
-- shared binds.lua has no reason to know about.
--
-- `locked` keeps them working while hyprlock is up -- being unable to turn the
-- backlight up on a dark lock screen is exactly when you want it most.
-- `repeating` lets the key auto-repeat while held.
local keys = { locked = true, repeating = true }

--------------------------
---- SCREEN BACKLIGHT ----
--------------------------

-- `-d intel_backlight` is not optional. This machine has TWO devices in
-- /sys/class/backlight -- intel_backlight (the panel) and nvidia_0 (the
-- discrete GPU, which has no display wired to it). brightnessctl with no -d
-- picks the first device it finds, which is nvidia_0, so the unqualified
-- command appears to work, reports a percentage, and changes nothing you can
-- see.
--
-- `-n` clamps the minimum to 1 rather than 0, so holding the down key cannot
-- black the panel out entirely and leave you hunting for it in the dark.
local backlight = "brightnessctl -d intel_backlight -n set "

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(backlight .. "5%+"), keys)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(backlight .. "5%-"), keys)

----------------------------
---- KEYBOARD BACKLIGHT ----
----------------------------

-- dell::kbd_backlight is an LED, not a backlight, hence -c leds. It has three
-- levels (0, 1, 2), so this steps by 1 rather than by a percentage -- 5% of a
-- range of 2 rounds to nothing.
--
-- Dell's firmware may already handle this key itself, in which case these
-- binds are redundant rather than harmful: check with `brightnessctl -c leds
-- -d dell::kbd_backlight get` before and after pressing it. If the level moves
-- by two steps at a time, the firmware is also acting on it -- delete these
-- two lines and let the firmware have it.
local kbd = "brightnessctl -c leds -d dell::kbd_backlight set "

hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd(kbd .. "+1"), keys)
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd(kbd .. "1-"), keys)

-------------------------------
---- LID SWITCH (CLAMSHELL) ----
-------------------------------

-- Close the lid with an external display attached and the built-in panel goes
-- away; open it and it comes back. Close it with nothing else attached and
-- this does nothing, because the machine should be suspending instead -- see
-- the logind note at the bottom.
--
-- `require` is cached, so this hands back the same table monitors.lua already
-- built rather than re-running its hl.monitor() calls.
local monitors = require("host").load("monitors")

-- hl.monitor() at runtime MERGES into the existing rule for that output name
-- and schedules a re-apply (CMonitorRuleParser copies the existing rule before
-- reading the table; CMonitorRuleManager::add calls scheduleReload). So
-- flipping `disabled` on its own keeps the panel's mode, position, scale and
-- vrr from monitors.lua -- there is no need to restate them here, and no
-- `hyprctl` shell-out either.
local function panel(on)
    hl.monitor({ output = monitors.PANEL, disabled = not on })
end

-- SW_LID reads 1 when the lid is CLOSED, so `switch:on` is the close event.
--
-- The monitor count is the guard. Disabling the only output would leave the
-- session with nowhere to draw, and Hyprland's unsafe-fallback state is not
-- somewhere to end up on purpose. It is also the same test logind uses to
-- decide the machine is "docked" (see hosts/LAPTOP-ON9AU/default.nix), so the two
-- halves of this agree by construction rather than by coincidence.
--
-- `locked` because closing the lid on a locked session is the common case, not
-- the exotic one -- without it this would silently do nothing whenever
-- hyprlock happened to be up.
hl.bind("switch:on:Lid Switch", function()
    if #hl.get_monitors() > 1 then
        panel(false)
    end
end, { locked = true })

hl.bind("switch:off:Lid Switch", function()
    panel(true)
end, { locked = true })

-- Two things to know:
--
--   * "Lid Switch" is libinput's usual name for it, but it is not guaranteed.
--     Confirm with `hyprctl devices` and correct both strings if it differs --
--     a switch bind on a name that does not exist fails silently.
--
--   * Unplugging the external display while the lid is shut leaves zero
--     outputs. Opening the lid fires switch:off and recovers it. There is no
--     handler for the unplug itself because doing it in that order is rare and
--     the recovery is one lid-open away.

