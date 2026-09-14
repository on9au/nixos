-- ~/.config/hypr/hyprland.lua -- Hyprland entry point.
--
-- ~/.config/hypr is a symlink to ~/nixos/dotfiles/config/hypr (home/desktop.nix),
-- so editing here edits the repo, and Hyprland reloads on save. No apply step.
--
-- This file only wires the modules together; the actual settings live in the
-- files listed below, all in this same directory.
--
--   colors.lua     Catppuccin Mocha palette, shared by the other modules
--   apps.lua       which terminal / browser / launcher to use
--   monitors.lua   per-output resolution, refresh rate and scaling
--   env.lua        environment variables for Wayland toolkits and the cursor
--   xwayland.lua   how X11 apps are scaled
--   looknfeel.lua  gaps, borders, rounding, blur, animations
--   input.lua      keyboard and mouse
--   binds.lua      keybindings
--   rules.lua      window and workspace rules
--   autostart.lua  processes started with the session
--   launch.lua     helpers autostart uses to start things under systemd
--
-- Two machines share this config -- a two-monitor desktop and a laptop -- and
-- the handful of settings that genuinely differ between them live in
-- hosts/<host>/, one file per topic. host.lua says which directory this
-- machine uses, from the hostname. Start there.
--
-- Reference:
--   Wiki      https://wiki.hypr.land/
--   Lua API   /run/current-system/sw/share/hypr/stubs/hl.meta.lua
--               (authoritative, versioned with the installed compositor)
--   Defaults  /run/current-system/sw/share/hypr/hyprland.lua
--
-- After editing, check for mistakes without logging out:
--   Hyprland --verify-config

require("monitors")
require("env")
require("xwayland")
require("looknfeel")
require("input")
require("binds")
require("rules")
require("autostart")
