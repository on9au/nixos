-- Monitors -- LAPTOP-ON9AU (Dell Pro Max 16 Premium), docked or on its own.
--
-- Physical layout when docked. The laptop sits on the desk to the LEFT of the
-- ultrawide -- beside it, not beneath it -- and low, because a laptop screen
-- starts at desk level while the monitor is up on a stand. So the two are
-- side by side with their BOTTOM edges flush:
--
--                        +------------------------------------------+
--                        |  Dell U4025QW  40"                       |
--                        |  5120x2160 @ 120Hz                       |
--                        |  scale 1.25 -> 4096x1728 logical         |
--                        |                                          |
--   +--------------------+                                          |
--   |  Samsung 16"       |                                          |
--   |  3840x2400         |                                          |
--   |  scale 2 ->        |                                          |
--   |  1920x1200         |                                          |
--   +--------------------+------------------------------------------+
--
-- The PANEL keeps `0x0` and the ultrawide is placed to its right at a negative
-- y, rather than the other way round. That way the undocked layout is
-- byte-for-byte what it was before the monitor existed -- nothing moves when
-- the cable comes out.
--
-- Do NOT use auto placement for the ultrawide -- `auto-right` is the tempting
-- one now, `auto-center-up` was when this sat above the panel, and the trap is
-- the same either way. Auto is resolved in enumeration order, and the wiki is
-- explicit
-- that a direction on the *first* monitor to come up does nothing and lands it
-- at (0,0). If the ultrawide enumerates before the panel it would collide with
-- the panel's explicit `0x0` and Hyprland would warn about overlap. Both
-- positions are spelled out so the order cannot matter.
--
-- To identify outputs after a cable change:  hyprctl monitors all

-- WHY NOT `output = "eDP-1"`:
--
-- The connector name is not stable on this machine. Same hardware, no config
-- change, different kernels:
--
--   kernel 7.1.6   i915 was card0   panel was eDP-2
--   kernel 7.1.8   i915 is  card1   panel is  eDP-1
--
-- simpledrm holds a DRM minor from the EFI framebuffer until a real driver
-- displaces it, and which of i915/nvidia lands on which minor depends on init
-- timing; the connector name follows. The nvidia card also exposes an eDP
-- connector of its own (nothing is wired to it), so both names exist in
-- /sys/class/drm at once. Matching on the EDID description survives all of it.
--
-- THE STRING BELOW IS UNVERIFIED. The panel's EDID carries manufacturer SDC
-- (Samsung Display) and model 16898 = 0x4202, but no product-name descriptor,
-- so the description Hyprland builds cannot be derived from the EDID alone.
-- Read the real one at the first Hyprland login and paste it here:
--
--   hyprctl monitors all          # the `description:` field
--
-- desc: is a PREFIX match against the description (and the short description),
-- so a leading fragment of it is enough -- see CMonitor::matchesStaticSelector.
-- If the string is wrong this block is simply inert and the catch-all below
-- still brings the panel up correctly -- see the note there.
local PANEL = "desc:Samsung Display Corp"

-- The 40" ultrawides at work, matched as a FAMILY rather than one serial.
--
-- Because desc: is a prefix match, stopping the string at "U40" covers the
-- whole Dell 40" 5K2K line (U4021QW / U4023QW / U4025QW ...) with one block.
-- They are all 5120x2160 across ~39.7", i.e. ~140 DPI, so one scale is right
-- for every one of them. It is a prefix, not a glob: "DELL U*" would not work.
--
-- The desk one is a U4025QW, EDID DEL 0x4308, serial 5D1BB34, 929.3 x 392.0 mm.
local ULTRAWIDE = "desc:Dell Inc. DELL U40"

-- Catch-all first: anything not matched below gets these.
--
-- Note the scale. On the desktop this line is a neutral fallback for a display
-- that gets plugged in; here it doubles as the safety net for the unverified
-- PANEL description above, so it is deliberately shaped like the built-in panel
-- -- preferred mode (which is 120Hz on this panel) at scale 2. The cost is that
-- an unrecognised external display comes up at scale 2 too, which on a 1080p
-- screen means a 960x540 logical desktop. That is wrong but obvious, and the
-- fix is to give that display its own hl.monitor block here (as ULTRAWIDE
-- below does) rather than to weaken the fallback for the screen that is always
-- there.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 2,
})

-- The built-in panel.
--
-- Why scale 2: the panel is ~283 DPI (348x223 mm), and 2 is what KDE was
-- using. It divides both axes evenly -- 1920x1200 exactly -- so nothing is
-- resampled. A fractional scale is where the blur on a panel this dense comes
-- from.
--
-- Why the mode is spelled out even though it equals `preferred`: unlike both
-- desktop monitors, this panel genuinely prefers 3840x2400@120, so
-- mode = "preferred" would be correct today. It is named anyway so that a
-- firmware or EDID change cannot quietly drop the session to 60Hz.
hl.monitor({
    output   = PANEL,
    mode     = "3840x2400@120",
    position = "0x0",
    scale    = 2,

    -- The panel reports a 30-120Hz VRR range, so this could be 1 (or 2, which
    -- also applies it to fullscreen-only). It is off because that is what KDE
    -- has been running, so this migration changes one thing at a time --
    -- brightness flicker at low refresh is the usual reason an eDP panel is
    -- left with VRR off. Try 1 once the session is otherwise settled.
    vrr = 0,
})

-- The ultrawide, to the right of the panel with their bottom edges flush.
--
-- x = 1920 is the panel's logical width, so the ultrawide's left edge starts
-- exactly where the panel's right edge ends: they touch, with no overlap and
-- no gap. y = 1200 - 1728 = -528 puts the two bottoms on the same line at
-- y = 1200. Negative positions are supported and are what keeps the panel on
-- the origin.
--
-- WHY BOTTOM-FLUSH AND NOT CENTRED ON THE PANEL, OR MATCHED TO THE STAND:
--
-- Bottom-flush is the only vertical offset with no dead zone at the seam. The
-- ultrawide spans y -528..1200 and the panel 0..1200, so the panel's range is
-- wholly inside the ultrawide's: every row of the panel has ultrawide to its
-- right, and the pointer crosses from anywhere on the panel without catching.
-- Nudge the ultrawide up and the bottom strip of the panel borders nothing,
-- which feels like the cursor sticking in a corner.
--
-- It is also close to the truth. The monitor is on a stand and the laptop is
-- flat on the desk, so physically the panel's bottom sits a little BELOW the
-- ultrawide's -- but only by the stand's clearance, and paying for that
-- accuracy with a sticky strip along the bottom of the panel is a bad trade.
--
-- Note the alignment is exact only along that bottom line. The panel is 1200
-- logical px across 223 mm of glass and the ultrawide 1728 across 392 mm, so
-- logical y and the physical centimetre drift apart as you go up. Nothing can
-- fix that while the two screens have different logical densities.
--
-- This was `0x-1728` (ultrawide directly above the panel, left edges flush)
-- and `-1088x-1728` (above and centred) before that. Both are wrong for a
-- laptop that lives beside the monitor rather than under it: they put the
-- crossing on the panel's TOP edge, so reaching the big screen meant pushing
-- the cursor up when the hardware is off to the right. Either is the value to
-- come back to if the laptop ever goes under the monitor again.
--
-- WHY `maxwidth` AND NOT `highres` OR AN EXPLICIT MODE:
--
-- Not an explicit mode, because these are shared work monitors -- some of the
-- 40" ultrawides here top out at 60Hz and some do 120Hz, and a hardcoded
-- 5120x2160@120 would be a modeset failure on half of them.
--
-- Not `highres`, which is the obvious choice and is broken for this shape of
-- panel. Its comparator (src/output/Monitor.cpp) is
--
--     a.pixelSize.x > b.pixelSize.x && a.pixelSize.y > b.pixelSize.y
--
-- so 5120x2160 vs 3840x2160 fails on `2160 > 2160`, and the equal-resolution
-- tiebreak needs x within 1px too. Every 2160-tall mode is therefore mutually
-- incomparable, and the sort behind it (std::ranges::sort) is not stable, so
-- which width you get is arbitrary.
--
-- Not `highrr` either: it sorts on refresh rate first and only breaks an exact
-- tie on resolution, so one fleet monitor advertising 1920x1080@144 would win
-- outright over 5120x2160@120. (hyprwm/Hyprland#9209.)
--
-- `maxwidth` is `a.x > b.x`, ties broken by higher refresh. A clean total
-- order, and exactly the rule wanted: widest mode, then fastest at that width.
-- Here that resolves to 5120x2160@120; on a 60Hz sibling, 5120x2160@60.
--
-- 5120x2160@120 is ~1485 MHz of pixel clock, about 35.6 Gbit/s -- more than
-- DP 1.4 HBR3 carries (25.92), so 120Hz only exists with DSC. It works over
-- this cable under Windows, so the link and the Arc iGPU can both do it, but
-- it is the first thing to suspect if the session comes up at 60. Nothing has
-- to be changed for that case: Hyprland keeps the best 3 modes plus the
-- preferred one as a fallback chain, so a failed modeset walks
-- 120 -> 100 -> 75 -> 60 instead of leaving the screen dark.
--
-- Scale 1.25 -> 4096x1728, both axes exact. At ~140 DPI this monitor is the
-- same density as the desktop's 32" AOC, which is also on 1.25, and it is what
-- Windows had it set to. Scale 1 would match the panel's logical density
-- exactly (283/2 vs 140) but assumes you sit as close to a 40" as to a 16".
hl.monitor({
    output   = ULTRAWIDE,
    mode     = "maxwidth",
    position = "1920x-528",
    scale    = 1.25,

    -- Same reasoning as the panel: the monitor advertises 48-120Hz adaptive
    -- sync, but nothing here has been verified against it yet.
    vrr = 0,
})

-- Exported so binds.lua can drive the lid switch without repeating the
-- selector strings. The desktop host's monitors.lua returns nothing, which is
-- fine -- only this host has a lid.
return {
    PANEL     = PANEL,
    ULTRAWIDE = ULTRAWIDE,
}
