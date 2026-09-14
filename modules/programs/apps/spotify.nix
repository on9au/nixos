{pkgs, ...}: {
  environment.systemPackages = [
    # Spotify (CEF) defaults to X11, and nixpkgs' wrapper doesn't pass the Ozone flags.
    (pkgs.symlinkJoin {
      name = "spotify-wayland";
      paths = [pkgs.spotify];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/spotify \
          --add-flags "--enable-features=UseOzonePlatform --ozone-platform=wayland"
      '';
    })
  ];

  # Spotify Connect local discovery.
  networking.firewall.allowedTCPPorts = [57621];
}
