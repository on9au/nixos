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
    settings = {
      # Not "max": on the desktop's ASUS firmware, Windows Boot Manager started
      # from sd-boot in that mode goes black and drops back to the menu.
      console-mode = "keep";
      # sd-boot sets EFI BootNext and reboots into Windows instead of
      # chainloading it, so the TPM measurements match what BitLocker sealed
      # against and Windows doesn't drop into recovery. Lanzaboote mkForce-
      # disables boot.loader.systemd-boot, so its rebootForBitlocker would do
      # nothing; this is the raw loader.conf key.
      reboot-for-bitlocker = "yes";
    };
  };

  environment.systemPackages = with pkgs; [
    sbctl
  ];
}
