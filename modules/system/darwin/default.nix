{pkgs, ...}: {
  imports = [
    ../nix/options.nix
    ./defaults.nix
    ./homebrew.nix
  ];

  # With the Determinate installer: nix.enable = false, and drop gc/optimise.
  # No auto-optimise-store here: on macOS it can corrupt the store, so the
  # timed nix.optimise below does the deduplication instead.
  nix.settings = {
    # 256 MiB; the 64 MiB default fills during big substitutions and warns.
    download-buffer-size = 268435456;
    experimental-features = ["flakes" "nix-command"];
    # Lets a project flake's nixConfig add its binary cache without sudo.
    trusted-users = ["@admin"];
  };
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
