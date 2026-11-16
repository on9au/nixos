{pkgs, ...}: {
  # Fan curves and modes. Its app is Qt; there is no GTK one, and the daemon
  # serves the same UI at http://localhost:11987.
  programs.coolercontrol.enable = true;

  environment.systemPackages = with pkgs; [
    # `sensors`: every fan and temperature at a glance, without the app.
    lm_sensors
  ];
}
