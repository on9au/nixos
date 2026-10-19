{
  config,
  pkgs,
  ...
}: {
  # The module's default package is the CLI only.
  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };

  # dumpcap's capture capabilities are limited to this group.
  users.users.${config.primaryUser}.extraGroups = ["wireshark"];
}
