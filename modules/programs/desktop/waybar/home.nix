{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  # TEMP(Waybar#5013): 0.15.0 sends `dispatch workspace`, a parse error under a
  # Lua Hyprland config, so workspace clicks do nothing. 0.16.0 has the fix;
  # until nixpkgs ships it, the git HEAD input does.
  # cava off: HEAD's libcava wrap no longer matches nixpkgs' pin, and no module uses it.
  waybar = assert lib.assertMsg (lib.versionOlder pkgs.waybar.version "0.16.0")
  "TEMP: nixpkgs has waybar ${pkgs.waybar.version}; drop the waybar flake input and the override in programs/desktop/waybar/home.nix";
    (pkgs.waybar.override {cavaSupport = false;}).overrideAttrs (old: {
      version = "0-unstable-${lib.substring 0 8 inputs.waybar.lastModifiedDate}";
      src = inputs.waybar;
      # New since 0.15.0 and needs ModemManager; no modem here.
      mesonFlags = old.mesonFlags ++ [(lib.mesonEnable "wwan" false)];
      # The binary still reports 0.15.0, which fails versionCheckHook.
      doInstallCheck = false;
    });
in {
  home.packages = with pkgs; [
    # gdbus, for config/scripts/kdeconnect.sh.
    glib
    # For config/scripts/privacy.sh.
    jq
    waybar
  ];

  xdg.configFile."waybar".source = config.lib.dotfiles.link ./config;
}
