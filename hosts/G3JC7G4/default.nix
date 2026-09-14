# NixOS-WSL on the Windows work laptop. Shell half only.
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    inputs.nixos-wsl.nixosModules.default
    ../../modules/nixos/common.nix
  ];

  wsl.enable = true;
  wsl.defaultUser = "djpro";

  networking.hostName = "G3JC7G4";
  nixpkgs.hostPlatform = "x86_64-linux";

  # The terminal is on the Windows side and can't draw kitty graphics.
  home-manager.users.djpro.dotfiles.inlineImages = false;

  system.stateVersion = "26.11";
}
