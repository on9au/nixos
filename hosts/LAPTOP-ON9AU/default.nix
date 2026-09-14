# Still on Arch. Generate the hardware config during the install, then git add it:
#   nixos-generate-config --root /mnt --show-hardware-config > hosts/LAPTOP-ON9AU/hardware-configuration.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/desktop.nix
  ];

  networking.hostName = "LAPTOP-ON9AU";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # VMD stall stopgap, see docs/LAPTOP-ON9AU-nvme-vmd-stalls.md. Drop once VMD is off in firmware.
  boot.kernelParams = [
    "nvme_core.io_timeout=5"
    "nvme.use_threaded_interrupts=1"
    "nvme_core.default_ps_max_latency_us=0"
  ];

  unfree.allow = [ "nvidia-x11" "nvidia-settings" ];

  services.xserver.videoDrivers = [ "modesetting" "nvidia" ];

  hardware.nvidia = {
    # Blackwell needs the open kernel modules.
    open = true;
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = true;

    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  environment.systemPackages = [
    # Arch's name for nvidia-offload, used in uwsm/env and the README.
    (pkgs.writeShellScriptBin "prime-run" ''exec nvidia-offload "$@"'')
  ];

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    # Clamshell: Hyprland disables the panel (hosts/LAPTOP-ON9AU/binds.lua).
    HandleLidSwitchDocked = "ignore";
  };

  services.fwupd.enable = true;

  system.stateVersion = "26.11";
}
