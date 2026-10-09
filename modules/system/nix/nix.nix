{...}: {
  nix.settings = {
    auto-optimise-store = true;
    # 256 MiB; the 64 MiB default fills during big substitutions and warns.
    download-buffer-size = 268435456;
    experimental-features = ["flakes" "nix-command"];
    # Lets a project flake's nixConfig add its binary cache without sudo.
    trusted-users = ["@wheel"];
  };
  nixpkgs.config.allowUnfree = true;

  nix.optimise.automatic = true;
}
