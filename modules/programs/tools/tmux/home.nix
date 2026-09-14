{
  config,
  lib,
  pkgs,
  ...
}: let
  nerd-font-window-name = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-nerd-font-window-name";
    version = "0-unstable-f464c59";
    rtpFilePath = "tmux-nerd-font-window-name.tmux";
    src = pkgs.fetchFromGitHub {
      owner = "joshmedeski";
      repo = "tmux-nerd-font-window-name";
      rev = "f464c59e459d91d7b0db702e2f436475c4e9bf4f";
      hash = "sha256-fsfhOmmAVwp/+kUcxi6ZvEfoNL1twJie8MhgNk/+UwE=";
    };
  };
in {
  programs.tmux = {
    enable = true;
    sensibleOnTop = false;
    terminal = "tmux-256color";
    prefix = "C-a";
    baseIndex = 1;
    historyLimit = 50000;
    escapeTime = 10;
    focusEvents = true;
    mouse = true;
    clock24 = true;

    # nix-style: ignore-order
    plugins = with pkgs.tmuxPlugins; [
      vim-tmux-navigator
      resurrect
      continuum
      cpu
      online-status
      battery
      nerd-font-window-name
      catppuccin
    ];
  };

  # Between home-manager's own settings (mkBefore) and the plugin block
  # (default order): plugins read these options when they load.
  xdg.configFile."tmux/tmux.conf".text = lib.mkOrder 750 (builtins.readFile ./tmux.conf);

  xdg.configFile."tmux/net-icon.sh".source = config.lib.dotfiles.link ./net-icon.sh;
}
