{...}: {
  services.smartd = {
    enable = true;

    # S/../../7/04 -> short test every Sunday, 04:00-05:00
    # L/../01/./04 -> long test on the 1st of each month, 04:00-05:00
    defaults.autodetected = "-a -s (S/../../7/04|L/../01/./04)";

    # Enables the systembus-notify user unit; failures only surface in a GUI
    # session, so a headless host wants mail or wall instead.
    notifications.systembus-notify.enable = true;
  };
}
