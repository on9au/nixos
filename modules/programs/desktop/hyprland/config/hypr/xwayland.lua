-- XWayland (X11 apps running under Wayland).
--
-- The problem this solves: an X11 app has no concept of display scaling. By
-- default Hyprland lets it render at the logical size -- 3072x1728 on the
-- desktop, 1920x1200 on the laptop -- and then upscales the result to fill the
-- panel, which is exactly the "blurry and too big" look Steam had.
--
-- force_zero_scaling instead hands X11 apps the panel's real pixel size
-- (3840x2160 or 3840x2400) and does no upscaling, so they render at native
-- pixel density and stay sharp. The trade-off is that an app which does not do
-- its own HiDPI scaling now draws everything at 1:1 and therefore looks
-- *small*; each such app needs telling how big to draw, by the scale factor of
-- the machine it is on -- 1.25 on the desktop, 2 on the laptop. Steam is
-- handled in ~/.config/uwsm/env (STEAM_FORCE_DESKTOPUI_SCALING), which is
-- templated per host for that reason.
--
-- Anything that speaks Wayland natively is unaffected by all of this -- the
-- better fix for any given app is to stop it using XWayland at all. Check
-- what is still on X11 with:
--
--   hyprctl clients -j | jq -r '.[] | select(.xwayland) | .class'
--
-- If some X11 app ends up too small and has no scaling option of its own,
-- flip this back to false rather than fighting it.
hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})
