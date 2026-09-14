{pkgs, ...}: {
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";

    fcitx5.addons = with pkgs; [
      fcitx5-gtk
      fcitx5-mozc
      qt6Packages.fcitx5-chinese-addons
    ];

    # Don't export GTK_IM_MODULE/QT_IM_MODULE; Wayland apps use text-input-v3 (see uwsm/env).
    fcitx5.waylandFrontend = true;

    # Default groups for a fresh ~/.config/fcitx5/profile.
    fcitx5.settings.inputMethod = {
      GroupOrder."0" = "Default";
      "Groups/0" = {
        "Default Layout" = "us";
        DefaultIM = "pinyin";
        Name = "Default";
      };
      "Groups/0/Items/0".Name = "keyboard-us";
      "Groups/0/Items/1".Name = "pinyin";
      "Groups/0/Items/2".Name = "mozc";
    };
  };
}
