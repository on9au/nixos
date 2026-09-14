{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = ["vmd" "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-uuid/fea8db5d-eecb-4a47-9eb6-956f4640662e";

  fileSystems."/" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = ["subvol=@" "compress=zstd:1" "noatime"];
  };

  fileSystems."/home" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = ["subvol=@home" "compress=zstd:1" "noatime"];
  };

  fileSystems."/nix" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = ["subvol=@nix" "compress=zstd:1" "noatime"];
  };

  fileSystems."/var/log" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = ["subvol=@log" "compress=zstd:1" "noatime"];
    neededForBoot = true;
  };

  fileSystems."/.snapshots" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = ["subvol=@snapshots" "compress=zstd:1" "noatime"];
  };

  fileSystems."/games" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = ["subvol=@games" "noatime"];
  };

  fileSystems."/swap" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = ["subvol=@swap" "noatime"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/FC68-C487";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
