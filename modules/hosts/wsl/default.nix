# NixOS-WSL on the Windows work laptop. Shell half only.
{config, ...}: {
  # nix-style: ignore-order
  imports = [
    # System
    ../../system

    # Users
    ../../users/djpro
    ../../home-manager

    # Shell and development
    ../../programs/development/claude-code
    ../../programs/development/neovim
    ../../programs/development/neovim/lsp
    ../../programs/development/toolchain
    ../../programs/tools
    ../../programs/tools/git
    ../../programs/tools/nh
    ../../programs/tools/ssh
    ../../programs/tools/tmux
    ../../programs/tools/zsh
  ];

  networking.hostName = "G3JC7G4";
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "26.11";

  wsl = {
    enable = true;
    defaultUser = config.primaryUser;
  };

  # WSL boot races the lingering user manager: its first start can fail with
  # EBUSY, leaving no user bus and breaking home-manager activation.
  systemd.services."user@".serviceConfig = {
    Restart = "on-failure";
    RestartSec = 2;
  };

  homeManagerModules = [
    {home.stateVersion = "26.05";}
  ];
}
