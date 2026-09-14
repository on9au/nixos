{...}: {
  homebrew.casks = ["ghostty"];

  homeManagerModules = [
    ./home.nix
  ];
}
