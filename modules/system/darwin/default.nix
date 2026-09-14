{pkgs, ...}: {
  imports = [
    ../nix/options.nix
    ./defaults.nix
    ./homebrew.nix
  ];

  # With the Determinate installer: nix.enable = false, and drop gc/optimise.
  nix.settings.experimental-features = ["flakes" "nix-command"];
  nixpkgs.config.allowUnfree = true;

  nix.gc = {
    automatic = true;
    interval = {
      Hour = 3;
      Minute = 0;
      Weekday = 0;
    };
    options = "--delete-older-than 30d";
  };

  nix.optimise.automatic = true;

  programs.zsh.enable = true;

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
  ];
}
