{pkgs, ...}: {
  imports = [
    ./graphics.nix
  ];

  hardware.amdgpu.initrd.enable = true;
  hardware.amdgpu.opencl.enable = true;

  environment.systemPackages = with pkgs; [
    amdgpu_top
    vulkan-tools
  ];
}
