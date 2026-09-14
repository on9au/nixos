{pkgs, ...}: {
  imports = [
    ./sober.nix
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
    prismlauncher # Minecraft instances and modpacks
    wineWowPackages.stable # Windows-only games and tools
    winetricks
  ];
}
