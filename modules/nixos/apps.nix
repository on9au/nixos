# Apps beyond the Hyprland session, each with what it is here for.
# The session basics autostart launches on both machines (Firefox, Discord,
# Spotify, Nautilus, Papers, Loupe) stay in home/desktop.nix.
{ config, lib, pkgs, inputs, ... }:

{
  imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

  unfree.allow = [
    "steam" "steam-unwrapped" "obsidian" "vscode" "reaper" "lunarclient" "osu-lazer-bin" "corefonts"
  ];

  home-manager.users.djpro.home.packages = with pkgs; [
    # ---- Everyday ----
    brave               # Chromium browser, for sites that only work properly in Chrome
    obsidian            # Markdown notes
    bitwarden-desktop   # password manager; handles bitwarden:// links (mimeapps.list)
    vscode              # GUI editor for projects that want its debuggers/extensions
    libreoffice-fresh   # opening and editing Office documents
    meld                # side-by-side diffs and merge conflicts
    mpv                 # default video player (mimeapps.list)
    vlc                 # fallback for videos and discs mpv won't play
    cinny-desktop       # Matrix chat
    spotatui            # Spotify from the terminal

    # ---- Games ----
    osu-lazer-bin       # osu!
    lunar-client        # Minecraft PvP client; handles lunarclient:// links
    prismlauncher       # Minecraft instances and modpacks
    mangohud            # FPS/frametime overlay
    wineWowPackages.stable
    winetricks          # Windows-only games and tools, with their runtime deps

    # ---- Creative / engineering ----
    krita               # drawing and painting, with the tablet
    reaper              # audio recording and mixing
    godot-mono          # game dev with C#
    logisim-evolution   # digital logic circuit simulation
    uxplay              # AirPlay receiver for mirroring an Apple device; run as `uxplay -p`
  ];

  programs.steam.enable = true;
  # Scales, frame-limits and HDRs individual games.
  programs.gamescope = { enable = true; capSysNice = true; };
  # Raises CPU governor and priority while a game runs.
  programs.gamemode.enable = true;

  # Roblox. Installed from Flathub by nix-flatpak when the system switches.
  services.flatpak.enable = true;
  services.flatpak.packages = [ "org.vinegarhq.Sober" ];

  # uxplay's fixed ports with -p.
  networking.firewall = {
    allowedTCPPorts = [ 7000 7001 7100 ];
    allowedUDPPorts = [ 6000 6001 7011 ];
  };

  fonts.packages = with pkgs; [
    corefonts           # Arial/Times/Verdana, for documents and sites that assume them
    liberation_ttf      # metric-compatible Arial/Times/Courier for LibreOffice
    carlito caladea     # metric-compatible Calibri/Cambria for Office files
    dejavu_fonts
    open-sans
    ttf_bitstream_vera
    noto-fonts          # the rest of Noto's scripts, beyond the CJK and emoji sets
  ];
}
