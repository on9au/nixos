{...}: {
  nix.settings.experimental-features = ["flakes" "nix-command"];
  nixpkgs.config.allowUnfree = true;

  nix.optimise.automatic = true;
}
