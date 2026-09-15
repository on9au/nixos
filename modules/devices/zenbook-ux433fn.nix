# Asus Zenbook 14 UX433FN, run as the homelab server.
{...}: {
  # It lives on AC, and the battery is its only UPS -- worth keeping healthy.
  # asus_wmi forgets the threshold at boot, and sometimes when the adapter is
  # replugged, which this does not catch.
  systemd.services.battery-charge-limit = {
    description = "Cap battery charge at 60%";
    wantedBy = ["multi-user.target"];
    script = "echo 60 > /sys/class/power_supply/BAT0/charge_control_end_threshold";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  # The MX150 draws power for nothing. With nouveau blacklisted nothing binds the
  # card, and an unbound PCI device stays powered until told to runtime-suspend.
  boot.blacklistedKernelModules = ["nouveau"];
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", ATTR{power/control}="auto"
  '';
}
