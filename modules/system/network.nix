{config, ...}: {
  users.users.${config.primaryUser}.extraGroups = ["networkmanager"];

  networking.networkmanager.enable = true;
}
