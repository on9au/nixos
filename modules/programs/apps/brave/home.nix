{...}: {
  # Shadows the package's entry to keep Brave out of fuzzel and "Open with";
  # it opens with SUPER + SHIFT + B (hypr/private.lua). The package's
  # com.brave.Browser entry, used by the portal, is already NoDisplay.
  xdg.desktopEntries.brave-browser = {
    name = "Brave Web Browser";
    exec = "brave %U";
    icon = "brave-browser";
    noDisplay = true;
    settings.StartupWMClass = "brave-browser";
  };
}
