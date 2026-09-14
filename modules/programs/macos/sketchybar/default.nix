{...}: {
  homebrew = {
    brews = [
      {
        name = "felixkratz/formulae/sketchybar";
        start_service = true;
      }
    ];
    # Homebrew 6 aborts the whole bundle on an untrusted tap.
    taps = [
      {
        name = "felixkratz/formulae";
        trusted = true;
      }
    ];
  };

  homeManagerModules = [
    ./home.nix
  ];
}
