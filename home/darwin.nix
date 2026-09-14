# macOS half: MBP-DYLAN.
{ config, lib, pkgs, ... }:

let
  inherit (config.lib.dotfiles) link;
in
{
  xdg.configFile = {
    "aerospace".source = link "config/aerospace";
    "sketchybar".source = link "config/sketchybar";
    "borders".source = link "config/borders";
    "ghostty".source = link "config/ghostty";
    # The directory, not karabiner.json: Karabiner replaces the file on save.
    "karabiner".source = link "config/karabiner";
  };

  home.packages = with pkgs; [
    # Apple's ssh has no FIDO2 provider.
    openssh
    libfido2
  ];
}
