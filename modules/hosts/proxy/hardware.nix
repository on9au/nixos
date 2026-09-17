# Written by hand: a KVM guest needs only the qemu-guest profile, and disko
# provides the filesystems.
{modulesPath, ...}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
}
