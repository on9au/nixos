-- Environment variables exported to everything Hyprland launches.
--
-- Note: these apply to processes started *by the compositor*. If you launch
-- Hyprland through uwsm (recommended, see the README), variables that need to
-- exist before the compositor starts belong in ~/.config/uwsm/env instead.

-- Cursor. Posy_Cursor_Black is an XCursor theme installed system-wide;
-- hyprcursor has no matching theme, so it falls back to XCursor on its own.
hl.env("XCURSOR_THEME", "Posy_Cursor_Black")
hl.env("XCURSOR_SIZE", "32")
hl.env("HYPRCURSOR_SIZE", "32")

-- Prefer native Wayland, fall back to XWayland where a toolkit needs it.
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Electron apps (VS Code, Discord, Obsidian) -- native Wayland instead of
-- blurry XWayland at 4K.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Qt: let the compositor handle scaling, and don't draw Qt's own titlebars
-- on top of Hyprland's borders.
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
