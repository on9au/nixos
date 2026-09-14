{pkgs, ...}: {
  programs.zsh.enable = true;
  # home-manager's zsh already runs compinit.
  programs.zsh.enableGlobalCompInit = false;

  users.defaultUserShell = pkgs.zsh;

  homeManagerModules = [
    ./home.nix
  ];
}
