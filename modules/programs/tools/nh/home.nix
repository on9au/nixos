{config, ...}: {
  # For nix-darwin, which has no nh module; NixOS hosts use default.nix instead.
  programs.nh = {
    enable = true;
    flake = "${config.home.homeDirectory}/nixos";
  };
}
