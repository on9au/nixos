{...}: {
  users.users.djpro = {
    isNormalUser = true;
    extraGroups = ["wheel"];
  };

  primaryUser = "djpro";

  homeManagerModules = [
    ./home.nix
  ];
}
