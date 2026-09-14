{pkgs, ...}: {
  users.users.djpro = {
    home = "/Users/djpro";
    shell = pkgs.zsh;
  };

  system.primaryUser = "djpro";

  primaryUser = "djpro";

  homeManagerModules = [
    ./home.nix
  ];
}
