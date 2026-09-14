{config, ...}: {
  programs.nh = {
    enable = true;
    flake = "/home/${config.primaryUser}/nixos";

    # Replaces nix.gc; nh warns when both are on.
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep-since 30d --keep 5";
    };
  };
}
