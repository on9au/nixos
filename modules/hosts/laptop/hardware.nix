# Hand-written ahead of the install so the flake evaluates before the disk
# exists, see ./install.md. Every UUID here is *forced* at mkfs time by the
# runbook rather than discovered afterwards, so this file is correct by
# construction. Diff it against `nixos-generate-config --show-hardware-config`
# during the install and reconcile the module lists if they differ.
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

  # "vmd" is load-bearing: the SN8000S sits behind the Intel VMD controller at
  # 0000:00:0e.0 and is invisible without it. See ./nvme-vmd-stalls.md.
  boot.initrd.availableKernelModules = ["vmd" "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  # nvme0n1p7, the partition EndeavourOS used. LUKS2, TPM2-unlocked at boot.
  boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-uuid/e873a998-2eac-4755-85cb-17a36baceb9e";

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

  # No compression: the swapfile lives here and btrfs refuses to swap on a
  # compressed or CoW extent.
  fileSystems."/swap" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = ["subvol=@swap" "noatime"];
  };

  # nvme0n1p1, the 420 MiB ESP *shared with Windows and Dell*. Not ours to
  # reformat - the runbook only deletes the EndeavourOS subtrees from it.
  # fmask/dmask keep it root-only despite vfat having no permission bits.
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/FE84-625A";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  # The swapfile is declared in ./default.nix, matching DESKTOP-DYLAN.
  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
