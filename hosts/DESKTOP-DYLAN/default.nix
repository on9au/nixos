{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.lanzaboote.nixosModules.lanzaboote
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/apps.nix
  ];

  networking.hostName = "DESKTOP-DYLAN";

  # Bootloader - ESP is shared with EndeavourOS
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    configurationLimit = 10;
    settings.console-mode = "max";
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 10;

  # systemd in initrd - required for FIDO2 LUKS unlock later
  boot.initrd.systemd.enable = true;
  boot.initrd.luks.devices."cryptroot".crypttabExtraOpts = [ "fido2-device=auto" ];

  # Swap
  swapDevices = [ { device = "/swap/swapfile"; } ];
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;

  services.btrfs.autoScrub.enable = true;
  services.btrfs.autoScrub.fileSystems = [ "/" ];

  desktop.greeterWallpaper = ./regreet-wallpaper.jpg;


  environment.systemPackages = with pkgs; [ sbctl ];

  system.stateVersion = "26.05";
}
