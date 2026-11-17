{...}: {
  # How GIO and xdg-open run `Terminal=true` entries such as nvim.desktop;
  # without it GIO falls back to a list kitty isn't on.
  xdg.terminal-exec = {
    enable = true;
    settings.default = ["kitty.desktop"];
  };

  homeManagerModules = [
    ./home.nix
  ];
}
