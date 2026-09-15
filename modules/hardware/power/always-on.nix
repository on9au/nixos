# A laptop used as a server, lid shut: nothing but these keeps it awake.
{...}: {
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  # Masked, so nothing -- a stray `systemctl suspend` included -- can sleep it.
  systemd.targets = {
    hibernate.enable = false;
    hybrid-sleep.enable = false;
    sleep.enable = false;
    suspend.enable = false;
  };
}
