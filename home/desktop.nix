# Hyprland half: DESKTOP-DYLAN and LAPTOP-ON9AU.
{ config, lib, pkgs, osConfig, inputs, ... }:

let
  inherit (config.lib.dotfiles) link;

  # 0.15.0 sends `dispatch workspace`, a parse error under a Lua Hyprland
  # config, so workspace clicks do nothing. Master sends hl.dsp.* instead.
  # cava off: master's libcava wrap no longer matches nixpkgs' pin, and no module uses it.
  waybar = (pkgs.waybar.override { cavaSupport = false; }).overrideAttrs (old: {
    version = "0-unstable-${lib.substring 0 8 inputs.waybar.lastModifiedDate}";
    src = inputs.waybar;
    # New since 0.15.0 and needs ModemManager; no modem here.
    mesonFlags = old.mesonFlags ++ [ (lib.mesonEnable "wwan" false) ];
    # The binary still reports 0.15.0, which fails versionCheckHook.
    doInstallCheck = false;
  });

  # Spotify (CEF) defaults to X11, and nixpkgs' wrapper doesn't pass the Ozone flags.
  spotify = pkgs.symlinkJoin {
    name = "spotify-wayland";
    paths = [ pkgs.spotify ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/spotify \
        --add-flags "--enable-features=UseOzonePlatform --ozone-platform=wayland"
    '';
  };
in
{
  home.packages = with pkgs; [
    waybar swaynotificationcenter fuzzel hypridle hyprshot hyprpicker
    cliphist wtype bemoji awww playerctl brightnessctl
    pavucontrol htop
    # gdbus, for waybar/scripts/kdeconnect.sh.
    glib
    kitty firefox nautilus
    papers loupe
    seahorse
    # Vencord built in; its installer can't patch a store path.
    (discord.override { withVencord = true; })
    spotify
    libfido2 yubikey-manager yubioath-flutter
  ];

  xdg.configFile = {
    "hypr".source = link "config/hypr";
    "waybar".source = link "config/waybar";
    "fuzzel".source = link "config/fuzzel";
    "swaync".source = link "config/swaync";
    "uwsm".source = link "config/uwsm";
    "kitty".source = link "config/kitty";
    "xdg-desktop-portal".source = link "config/xdg-desktop-portal";
    "winapps".source = link "config/winapps";

    # Apps that save these replace the link with a real file; the next switch
    # moves it aside as .chezmoi-bak.
    "mimeapps.list".source = link "config/mimeapps.list";
  };

  gtk = {
    enable = true;
    theme = {
      name = "catppuccin-mocha-mauve-standard";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "mauve" ];
        variant = "mocha";
      };
    };
    # libadwaita ignores gtk-theme-name; this imports the theme's CSS instead.
    gtk4.theme = config.gtk.theme;
  };
  # GTK4/libadwaita apps take dark mode from here, not from gtk.theme.
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  home.file = lib.listToAttrs (map
    (name: lib.nameValuePair ".local/bin/${name}" { source = link "local-bin/${name}"; })
    [ "colorpicker" "emoji" "nolock" "powermenu" ]);

  # programs.ssh.startAgent only exports SSH_AUTH_SOCK to shells, not the user manager.
  systemd.user.sessionVariables = {
    SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-agent";
    SSH_ASKPASS = osConfig.programs.ssh.askPassword;
  };

  # Discord and Steam recreate these when their launch-on-startup toggle is
  # used; uwsm would start a second copy alongside hypr/hosts/*/autostart.lua.
  home.activation.removeDuplicateAutostart = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run rm -f $VERBOSE_ARG \
      "${config.xdg.configHome}/autostart/discord.desktop" \
      "${config.xdg.configHome}/autostart/steam.desktop"
  '';
}
