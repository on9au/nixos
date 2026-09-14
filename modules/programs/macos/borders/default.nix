{...}: {
  homebrew = {
    brews = [
      {
        name = "felixkratz/formulae/borders";
        start_service = true;
      }
    ];
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
