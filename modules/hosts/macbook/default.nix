# Needs Nix and Homebrew installed first, then:
#   sudo nix run nix-darwin -- switch --flake ~/nixos#MBP-DYLAN
{...}: {
  # nix-style: ignore-order
  imports = [
    # System
    ../../system/darwin

    # Users
    ../../users/djpro/darwin.nix
    ../../home-manager

    # Desktop
    ../../programs/macos/aerospace
    ../../programs/macos/apps.nix
    ../../programs/macos/borders
    ../../programs/macos/ghostty
    ../../programs/macos/karabiner
    ../../programs/macos/sketchybar

    # Shell and development
    ../../programs/development/claude-code
    ../../programs/development/neovim
    ../../programs/development/neovim/images
    ../../programs/development/neovim/lsp
    ../../programs/development/roblox
    ../../programs/tools/git
    ../../programs/tools/ssh
    ../../programs/tools/tmux
  ];

  networking.hostName = "MBP-DYLAN";
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;

  # These modules' default.nix files are NixOS-only, so their home halves come in directly.
  # nix-style: ignore-order
  homeManagerModules = [
    ../../hardware/peripherals/yubikey/home.nix
    ../../programs/development/toolchain/home.nix
    ../../programs/tools/home.nix
    ../../programs/tools/nh/home.nix
    ../../programs/tools/zsh/home.nix
    {home.stateVersion = "26.05";}
  ];
}
