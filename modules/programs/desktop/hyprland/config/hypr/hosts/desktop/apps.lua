-- Per-machine values for apps.lua -- the two-screen desktop.

return {
    -- Native 3840x2160, so it fits both panels exactly -- the 3840x1080 files
    -- in that folder are from the old dual-1080p setup and will letterbox
    -- badly on these screens.
    wallpaper = os.getenv("HOME") .. "/Pictures/Wallpapers/wallhaven-je8p85.jpg",
}
