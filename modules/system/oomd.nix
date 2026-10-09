{...}: {
  # systemd-oomd already runs but watches no cgroups. With these it kills the
  # app scope under memory pressure before the desktop locks up; earlyoom
  # would be a second killer racing it.
  systemd.oomd = {
    enableRootSlice = true;
    enableUserSlices = true;
  };
}
