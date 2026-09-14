{
  lib,
  pkgs,
  ...
}: {
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    configurationLimit = 10;
    settings.console-mode = "max";
  };

  environment.systemPackages = with pkgs; [
    sbctl
  ];
}
