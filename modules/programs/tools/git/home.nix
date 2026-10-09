{pkgs, ...}: {
  programs.git.enable = true;

  programs.git.settings.alias.graph = "log --all --decorate --oneline --graph";

  # Defines the catppuccin-mocha feature that delta's options below turn on.
  programs.git.includes = [
    {path = "${pkgs.catppuccin.override {variant = "mocha";}}/delta/catppuccin.gitconfig";}
  ];

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      features = "catppuccin-mocha";
      navigate = true;
    };
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };
}
