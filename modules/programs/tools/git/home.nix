{pkgs, ...}: {
  programs.git.enable = true;

  programs.git.settings.alias.graph = "log --all --decorate --oneline --graph";

  programs.git.includes = [
    # Defines the catppuccin-mocha feature that delta's options below turn on.
    {path = "${pkgs.catppuccin.override {variant = "mocha";}}/delta/catppuccin.gitconfig";}
    # The repo is public: its pre-commit hook runs gitleaks over staged changes.
    {
      condition = "gitdir:~/nixos/";
      contents.core.hooksPath = ".githooks";
    }
  ];

  home.packages = with pkgs; [gitleaks];

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
