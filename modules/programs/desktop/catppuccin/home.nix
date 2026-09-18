{
  config,
  pkgs,
  ...
}: {
  gtk = {
    enable = true;
    theme = {
      name = "catppuccin-mocha-mauve-standard";
      package = pkgs.catppuccin-gtk.override {
        accents = ["mauve"];
        variant = "mocha";
      };
    };
    # libadwaita ignores gtk-theme-name; this imports the theme's CSS instead.
    gtk4.theme = config.gtk.theme;
  };

  # GTK4/libadwaita apps take dark mode from here, not from gtk.theme.
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  qt = {
    enable = true;

    # qt5ct/qt6ct, not the gtk3 platform theme this replaces (see uwsm/env):
    # gtk3 hands Qt the GTK palette, which paints over whatever the widget
    # style draws, so Kvantum's colours would never show.
    platformTheme.name = "qtct";
    style.name = "kvantum";

    kvantum = {
      enable = true;
      themes = [
        (pkgs.catppuccin-kvantum.override {
          accent = "mauve";
          variant = "mocha";
        })
      ];
      settings.General.theme = "catppuccin-mocha-mauve";
    };

    # standard_dialogs keeps the GTK file picker the gtk3 platform theme gave.
    qt5ctSettings.Appearance = {
      standard_dialogs = "gtk3";
      style = "kvantum";
    };
    qt6ctSettings.Appearance = {
      standard_dialogs = "gtk3";
      style = "kvantum";
    };
  };
}
