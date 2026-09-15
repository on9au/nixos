{...}: {
  programs.git.enable = true;

  programs.git.settings.alias.graph = "log --all --decorate --oneline --graph";

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };
}
