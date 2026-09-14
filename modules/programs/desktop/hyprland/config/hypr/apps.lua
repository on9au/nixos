-- Default applications, referenced from binds.lua and rules.lua.
-- Change them here once instead of hunting through the keybindings.

local host_apps = require("host").load("apps")

return {
	terminal = "kitty",
	file_manager = "nautilus",
	launcher = "fuzzel",
	browser = "firefox",

	-- Screenshots land here; hyprshot creates the directory if missing.
	screenshot_dir = os.getenv("HOME") .. "/Pictures/Screenshots",

	-- Spotify, named once because both host autostart files launch it at every
	-- login. Native Wayland via the wrapper in programs/apps/spotify.nix.
	music = "spotify",

	-- Wallpaper shown at login (see autostart.lua). Per-machine, because the
	-- panels are not the same shape -- 16:10 on the laptop, 16:9 on the
	-- desktop -- and the wrong one crops or letterboxes.
	wallpaper = host_apps.wallpaper,
}
