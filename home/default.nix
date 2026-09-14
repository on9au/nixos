# Shell half: every machine.
{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles;

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
in
{
  options.dotfiles = {
    # Links point at the checkout, not the store, so edits apply without a rebuild.
    root = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/nixos/dotfiles";
    };

    # Snacks.image / diagram.nvim rendering; needs a kitty-graphics terminal.
    inlineImages = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = {
    lib.dotfiles.link = path: config.lib.file.mkOutOfStoreSymlink "${cfg.root}/${path}";

    home.stateVersion = "26.05";

    home.packages = with pkgs; [
      fzf less jq unzip
      neovim tree-sitter ripgrep fd lazygit sqlite
      fnm nodejs
      claude-code
      yazi zoxide fastfetch tldr tree duf glances smartmontools iperf3
      _7zz zip unrar exiftool dnsutils upx cbonsai sl
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ wl-clipboard inxi hwinfo whois ]
    ++ lib.optionals cfg.inlineImages [ imagemagick ghostscript tectonic mermaid-cli ];

    xdg.configFile = {
      "nvim".source = config.lib.dotfiles.link "config/nvim";
      "mermaid".source = config.lib.dotfiles.link "config/mermaid";
      "tmux/net-icon.sh".source = config.lib.dotfiles.link "tmux/net-icon.sh";
    };

    programs.zsh = {
      enable = true;
      enableCompletion = true;

      history = {
        path = "${config.home.homeDirectory}/.zsh_history";
        size = 50000;
        save = 50000;
        extended = true;
      };

      # Same order as the old .zsh_plugins.txt.
      plugins = [
        {
          name = "omz-git";
          src = "${pkgs.oh-my-zsh}/share/oh-my-zsh/plugins/git";
          file = "git.plugin.zsh";
        }
        { name = "zsh-vi-mode"; src = "${pkgs.zsh-vi-mode}/share/zsh-vi-mode"; }
        { name = "fzf-tab"; src = "${pkgs.zsh-fzf-tab}/share/fzf-tab"; }
        # A plugin rather than autosuggestion.enable, which loads before fzf-tab.
        {
          name = "zsh-autosuggestions";
          src = "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions";
          file = "zsh-autosuggestions.zsh";
        }
      ];
      historySubstringSearch.enable = true;
      syntaxHighlighting.enable = true;

      envExtra = builtins.readFile ../dotfiles/zsh/zshenv.zsh;

      initContent = lib.mkMerge [
        (lib.mkOrder 550 "fpath=(~/.zsh/completion $fpath)")
        # After every plugin, so SDKMAN's init stays last.
        (lib.mkOrder 1300 (builtins.readFile ../dotfiles/zsh/zshrc.zsh))
      ];
    };

    programs.starship.enable = true;

    # Per-project toolchains: `use flake` in .envrc loads that project's dev shell on cd.
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

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
    xdg.configFile."tmux/tmux.conf".text = lib.mkOrder 750 (builtins.readFile ../dotfiles/tmux/tmux.conf);

    programs.git = {
      enable = true;
      settings.user = {
        name = "on9au";
        email = "151502370+on9au@users.noreply.github.com";
      };
    };

    programs.gh = {
      enable = true;
      gitCredentialHelper.enable = true;
    };
  };
}
