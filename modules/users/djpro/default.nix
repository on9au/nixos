{...}: {
  users.users.djpro = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keyFiles = [./authorized_keys];
  };

  primaryUser = "djpro";

  homeManagerModules = [
    ./home.nix
  ];
}
