{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    envExtra = builtins.readFile ./zshenv.zsh;

    history = {
      extended = true;
      path = "${config.home.homeDirectory}/.zsh_history";
      save = 50000;
      size = 50000;
    };

    historySubstringSearch.enable = true;
    syntaxHighlighting.enable = true;

    initContent = lib.mkMerge [
      (lib.mkOrder 550 "fpath=(~/.zsh/completion $fpath)")
      (lib.mkOrder 1300 (builtins.readFile ./zshrc.zsh))
    ];

    # Same order as the old .zsh_plugins.txt.
    # nix-style: ignore-order
    plugins = [
      {
        name = "omz-git";
        src = "${pkgs.oh-my-zsh}/share/oh-my-zsh/plugins/git";
        file = "git.plugin.zsh";
      }
      {
        name = "zsh-vi-mode";
        src = "${pkgs.zsh-vi-mode}/share/zsh-vi-mode";
      }
      {
        name = "fzf-tab";
        src = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
      }
      # A plugin rather than autosuggestion.enable, which loads before fzf-tab.
      {
        name = "zsh-autosuggestions";
        src = "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions";
        file = "zsh-autosuggestions.zsh";
      }
    ];
  };

  # `use flake` in a project's .envrc loads its dev shell on cd.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.starship.enable = true;
}
