{...}: {
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    # Clamshell: Hyprland disables the panel (hypr/hosts/LAPTOP-ON9AU/binds.lua).
    HandleLidSwitchDocked = "ignore";
  };
}
