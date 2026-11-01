{pkgs, ...}: {
  users.users.djpro = {
    home = "/Users/djpro";
    openssh.authorizedKeys.keyFiles = [./authorized_keys];
    shell = pkgs.zsh;
  };

  system.primaryUser = "djpro";

  primaryUser = "djpro";

  homeManagerModules = [
    ./home.nix
  ];
}
