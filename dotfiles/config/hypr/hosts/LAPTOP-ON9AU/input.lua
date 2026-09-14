-- Pointing devices -- LAPTOP-ON9AU.
--
-- A touchpad, a touchscreen, and -- when docked -- an external mouse, which
-- gets its own block at the bottom. The touchscreen needs no configuration:
-- libinput maps it to the only output on its own.

-- Only the leaves named here are changed; the keyboard and cursor settings in
-- input.lua are left alone.
hl.config({
    input = {
        -- Off here, inherited as `true` from the desktop, which has a
        -- full-size keyboard with a numpad.
        --
        -- Whether this keyboard has one was not established: the kernel's
        -- "AT Translated Set 2 keyboard" advertises the whole standard keymap
        -- including KP0-KP9 whether the keys physically exist or not, so the
        -- capability bits prove nothing either way. If there is no numpad this
        -- setting does nothing at all; if there is one, its keys start as
        -- navigation keys and one press of Num Lock fixes it for good. Flip to
        -- true if that turns out to be annoying.
        numlock_by_default = false,

        touchpad = {
            -- Both carried over from KDE, which had them set on this exact
            -- device (kcminputrc,
            -- [Libinput][1739][53241][VEN_06CB:00 06CB:CFF9 Touchpad]):
            --   NaturalScroll=true
            --   DisableWhileTyping=false
            natural_scroll      = true,
            disable_while_typing = false,

            -- KDE had no entry for these, which means its defaults were in
            -- effect: tapping counts as a click, and tap-then-drag works.
            -- Hyprland defaults both to off, so they are set explicitly rather
            -- than silently lost in the move.
            tap_to_click  = true,
            tap_and_drag  = true,

            -- Two-finger scroll speed. Unlike the desktop's mouse sensitivity
            -- this is not derived from anything -- KDE exposes no equivalent
            -- number to carry over, and Hyprland's 1.0 scrolls a touchpad
            -- noticeably faster than Plasma did. This is a starting point and
            -- the only number here worth touching: raise it toward 1.0 if
            -- scrolling feels sluggish, lower it if a flick overshoots.
            scroll_factor = 0.6,
        },
    },
})

-- The touchpad needs no hl.device block of its own: there is only one, so the
-- input.touchpad section above already addresses it unambiguously. If a
-- per-device setting is ever needed, the name Hyprland knows it by is
-- `ven_06cb:00-06cb:cff9-touchpad`. Confirm with `hyprctl devices` first.

--------------------------
---- POINTER FEEL      ----
--------------------------

-- The external mouse -- a Dell wireless combo on the Dell Universal Receiver
-- (usb 413c:2514).
--
-- The receiver is not plugged into the laptop. It sits behind the chain of
-- Realtek hubs that also carries the 2.5G ethernet, i.e. the U4025QW's own USB
-- hub, so this device exists only while docked. Nothing has to guard for that:
-- an hl.device rule naming hardware that is not attached is simply inert, the
-- same way the desktop's mouse rule is inert here.
--
-- Two mice reach this machine over USB and only this one is configured. The
-- other -- `cx-2.4g-wireless-receiver-mouse`, usb 3554:fa09, a Compx dongle --
-- is deliberately left on libinput's defaults, because it was not the one that
-- felt wrong. Do not collapse the two into a global `input.accel_profile`:
-- that would catch the touchpad as well, where adaptive acceleration is
-- exactly what you want.
--
-- WHY THESE TWO VALUES:
--
-- accel_profile is the entire fix. libinput's default profile is "adaptive",
-- which scales pointer movement by how fast you are already moving -- roughly
-- 2.5x on a quick flick and below 1x when creeping. "flat" is raw 1:1: the
-- same hand movement always covers the same distance, which is what "disable
-- mouse acceleration" means.
--
-- sensitivity = 0 applies that flat profile untouched, and unlike the
-- desktop's mouse there is no number to carry over -- kcminputrc has no
-- [Libinput] section for 413c:2514, so KDE never overrode this device either.
-- Starting from no override keeps the two configs honest about that.
--
-- This is the one number worth touching if it still feels wrong. On the flat
-- profile it is a plain multiplier of (1 + sensitivity), so -0.2 is -20%; the
-- range is -1.0 to 1.0.
--
-- Before reaching for it, though, two things upstream of it:
--
-- 1. The mouse's own DPI, if it has a button for it. That is the honest place
--    to fix "too fast" -- it costs nothing in precision, whereas a negative
--    sensitivity throws away real motion data.
--
-- 2. Monitor scale, which is why one number cannot be right everywhere on this
--    machine. The pointer moves in LOGICAL pixels, so its speed across the
--    glass follows each screen's logical density: the panel is 283 DPI at
--    scale 2, about 142 logical px/inch, and the ultrawide is 140 DPI at
--    scale 1.25, about 112. The pointer therefore travels ~26% further per
--    inch of hand movement on the ultrawide than on the panel. One pointer
--    cannot have two speeds, so tune for whichever screen the mouse is
--    actually used on -- which, since the receiver is in the monitor, is the
--    ultrawide.
hl.device({
    name = "dell-computer-corp-dell-universal-receiver-mouse",

    accel_profile = "flat",
    sensitivity   = 0,
})
