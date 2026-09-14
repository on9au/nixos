{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    godot-mono # game dev with C#
    krita # drawing and painting, with the tablet
    logisim-evolution # digital logic circuit simulation
    reaper # audio recording and mixing
    uxplay # AirPlay receiver for mirroring an Apple device; run as `uxplay -p`
  ];

  # uxplay's fixed ports with -p.
  networking.firewall = {
    allowedTCPPorts = [7000 7001 7100];
    allowedUDPPorts = [6000 6001 7011];
  };
}
