{...}: {
  # What services.syncthing.openDefaultPorts opens; syncthing itself runs from
  # home-manager, as the user who owns the synced folders.
  networking.firewall = {
    allowedTCPPorts = [22000];
    allowedUDPPorts = [21027 22000];
  };

  homeManagerModules = [./home.nix];
}
