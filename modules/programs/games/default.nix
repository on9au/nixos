{pkgs, ...}: {
  imports = [
    ./roblox.nix
  ];

  programs.steam.enable = true;

  # Scales, frame-limits and HDRs individual games.
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # Raises CPU governor and priority while a game runs.
  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    lunar-client # Minecraft PvP client; handles lunarclient:// links
    mangohud # FPS/frametime overlay
    osu-lazer-bin
    # Minecraft instances and modpacks. libxkbcommon is needed by LWJGL's SDL3 Wayland
    # backend; the rest are loaded by Java's AWT (mods using ImageIO, e.g. Distant Horizons).
    (prismlauncher.override {
      additionalLibs = [
        freetype
        libxi
        libxkbcommon
        libxrender
        libxtst
      ];
    })
    winetricks
  ];
}
