# Input method (fcitx5)

`i18n.inputMethod` in `input-method.nix`, with the engines in
`fcitx5.addons`. That is also what owns the D-Bus activation this repo used to
override; see [Tray](waybar/README.md#tray).

Groups are configured in `fcitx5/profile`: `keyboard-us`, `pinyin`, `mozc`.
Toggle with `SUPER`+`Space`, GUI via `fcitx5-configtool`.

fcitx5 is **not** in `hypr/autostart.lua` on purpose, and nothing in this repo
starts it. Its own package does, twice over — D-Bus activation on the first
request for the `org.fcitx.Fcitx5` name, and an XDG autostart entry that uwsm
runs as `app-org.fcitx.Fcitx5@autostart.service`. Adding it to autostart.lua
would only run a second copy.

The variables it needs live in `uwsm/env`, not `hypr/env.lua`, because fcitx5
is launched by systemd rather than by the compositor — `hl.env()` would never
reach it. Only `XMODIFIERS` is set for toolkits: Hyprland speaks
text-input-v3, so Wayland-native GTK/Qt apps reach fcitx5 through the
compositor, and setting `GTK_IM_MODULE`/`QT_IM_MODULE` there tends to *break*
them. Those two are left commented out in `uwsm/env` for the XWayland-only
apps that occasionally need them.

```bash
systemctl --user restart app-org.fcitx.Fcitx5@autostart.service   # after changes
```

