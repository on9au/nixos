{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    furnace # chiptune tracker
    # The Linux build doesn't install the demo songs the docs walk through.
    (runCommand "furnace-demos" {} ''
      mkdir -p $out/share/furnace
      ln -s ${furnace.src}/demos $out/share/furnace/demos
    '')
    godot-mono # game dev with C#
    krita # drawing and painting, with the tablet
    reaper # audio recording and mixing
    uxplay # AirPlay receiver for mirroring an Apple device; run as `uxplay -p`
    zenity # furnace's system file picker
  ];

  # For the demos above, at /run/current-system/sw/share/furnace/demos.
  environment.pathsToLink = ["/share/furnace"];

  # screen and webcam recording
  programs.obs-studio.enable = true;

  # uxplay advertises itself through Avahi, which refuses to publish by default.
  services.avahi.publish = {
    enable = true;
    userServices = true;
  };

  # uxplay's fixed ports with -p.
  networking.firewall = {
    allowedTCPPorts = [7000 7001 7100];
    allowedUDPPorts = [6000 6001 7011];
  };
}
