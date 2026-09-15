{...}: {
  users.users.opena0 = {
    isNormalUser = true;
    extraGroups = ["wheel"];

    # The primary and backup YubiKeys' resident keys; fingerprints in
    # programs/services/ssh-agent/README.md.
    openssh.authorizedKeys.keys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDiCaaNsRXWBWPiCeuJlB31rLySKiJfaesgsTxisQZvhAAAABHNzaDo= primary"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAILy3rMccWoJ7Poelw1v4nOAc/5IArdaAT3G0zxcfSLWHAAAABHNzaDo= backup"
    ];
  };

  primaryUser = "opena0";

  # Same person as users/djpro under a different account name, so the git
  # identity is the shared one rather than a second copy.
  homeManagerModules = [
    ../djpro/home.nix
  ];
}
