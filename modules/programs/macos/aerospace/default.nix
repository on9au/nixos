{...}: {
  homebrew = {
    casks = ["nikitabobko/tap/aerospace"];
    # Homebrew 6 aborts the whole bundle on an untrusted tap.
    taps = [
      {
        name = "nikitabobko/tap";
        trusted = true;
      }
    ];
  };

  homeManagerModules = [
    ./home.nix
  ];
}
