{...}: {
  xdg.desktopEntries = {
    phone-mirror = {
      name = "Phone Mirroring";
      genericName = "Android screen mirroring";
      exec = "phone-mirror";
      icon = "scrcpy";
      settings.Keywords = "scrcpy;android;adb;";
      settings.StartupWMClass = ".scrcpy-wrapped";
    };

    # Shadow the package's entries: they run a bare scrcpy through an
    # interactive shell and fail silently when the phone isn't connected.
    scrcpy = {
      name = "scrcpy";
      exec = "scrcpy";
      noDisplay = true;
    };
    scrcpy-console = {
      name = "scrcpy (console)";
      exec = "scrcpy";
      noDisplay = true;
    };
  };
}
