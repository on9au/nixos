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
}
