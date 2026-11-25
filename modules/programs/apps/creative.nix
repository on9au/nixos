{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    decent-sampler # sampled instruments (pianos etc.), as a plugin for reaper
    furnace # chiptune tracker
    # The Linux build doesn't install the demo songs the docs walk through.
    (runCommand "furnace-demos" {} ''
      mkdir -p $out/share/furnace
      ln -s ${furnace.src}/demos $out/share/furnace/demos
    '')
    godot-mono # game dev with C#
    krita # drawing and painting, with the tablet
    openutau # singing synthesis, a free Vocaloid alternative
    reaper # audio recording and mixing
    sfizz-ui # SFZ sample player plugin for reaper, for the piano below
    # Sampled grand piano with release samples, at
    # /run/current-system/sw/share/sounds/sfz/salamander-grand-piano.
    (runCommand "salamander-grand-piano" {} ''
      mkdir -p $out/share/sounds/sfz
      ln -s ${fetchzip {
        url = "https://freepats.zenvoid.org/Piano/SalamanderGrandPiano/SalamanderGrandPiano-SFZ+FLAC-V3+20200602.tar.gz";
        hash = "sha256-he9LsLg+6oHL68xH8x0e3E1K/L7sUhK87s7jPPw/2Rk=";
      }} $out/share/sounds/sfz/salamander-grand-piano
    '')
    surge-xt # synth, standalone and as a plugin for reaper
    uxplay # AirPlay receiver for mirroring an Apple device; run as `uxplay -p`
    zenity # furnace's system file picker
  ];

  # REAPER only loads extensions from its own config folder.
  homeManagerModules = [
    {
      xdg.configFile."REAPER/UserPlugins/reaper_reapack-x86_64.so".source = "${pkgs.reaper-reapack-extension}/UserPlugins/reaper_reapack-x86_64.so";
    }
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
