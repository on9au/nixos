{...}: {
  users.users.opena0 = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keyFiles = [../djpro/authorized_keys];
  };

  primaryUser = "opena0";

  # Same person as users/djpro under a different account name, so the git
  # identity is the shared one rather than a second copy.
  homeManagerModules = [
    ../djpro/home.nix
  ];
}
