{...}: {
  homebrew.casks = ["karabiner-elements"];

  homeManagerModules = [
    ./home.nix
  ];
}
