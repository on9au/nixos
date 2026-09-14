{pkgs, ...}: {
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      foomatic-db-ppds
      gutenprint
    ];
  };

  programs.system-config-printer.enable = true;

  # Network printers, AirPlay and .local names.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
