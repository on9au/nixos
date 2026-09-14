-- Per-machine values for apps.lua -- LAPTOP-ON9AU.

return {
    -- The panel is 3840x2400, which is 16:10. The desktop's wallpaper is
    -- 3840x2160 (16:9) and would be cropped or letterboxed here, so this
    -- machine gets its own file, matching the panel pixel for pixel.
    --
    -- The greeter cannot read /home/djpro; give it a copy in the repo via
    -- desktop.greeterWallpaper in hosts/LAPTOP-ON9AU/default.nix.
    wallpaper = os.getenv("HOME") .. "/Pictures/Wallpapers/wallpaper-3840x2400.png",
}
