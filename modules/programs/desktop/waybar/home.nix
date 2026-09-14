{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  # 0.15.0 sends `dispatch workspace`, a parse error under a Lua Hyprland
  # config, so workspace clicks do nothing. The git HEAD input sends hl.dsp.*.
  # cava off: HEAD's libcava wrap no longer matches nixpkgs' pin, and no module uses it.
  waybar = (pkgs.waybar.override {cavaSupport = false;}).overrideAttrs (old: {
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
    waybar
  ];

  xdg.configFile."waybar".source = config.lib.dotfiles.link ./config;
}
