{pkgs, ...}: {
  services.hardware.openrgb.enable = true;

  environment.systemPackages = [
    (pkgs.writers.writePython3Bin "rgb-state" {
        libraries = [pkgs.python3Packages.openrgb-python];
      }
      ./rgb-state.py)
  ];
}
