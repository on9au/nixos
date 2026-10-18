# Waybar

## Built from git

waybar is the `waybar` flake input, built with nixpkgs' recipe in
[`home.nix`](home.nix), rather than the 0.15.0 release. The release sends
`hyprctl dispatch workspace name:<n>` when you click a workspace, which is a
[parse error](../hyprland/README.md#the-lua-config-gotcha) under Hyprland's Lua
config, so clicking did nothing. Master detects a Lua config and emits
`hl.dsp.focus({ workspace = "..." })` instead. Going back to a release loses
workspace clicking again until one includes that change.

`nix flake update waybar` moves it to the latest commit, and can break the
build when upstream adds a dependency nixpkgs' recipe doesn't have.

## Tray

The tray hides fcitx5's language icon, because `custom/fcitx5` sits
immediately right of it and says the same thing in two characters. One line in
`waybar/config.jsonc`:

```jsonc
"ignore-list": ["Fcitx", "fcitx"]
```

An item is hidden when any string in the list appears as a **substring** of its
bus name, category, icon name, id or title. Both spellings are there because
the match is case-sensitive and fcitx5 uses `Fcitx` in its id and title but
`fcitx` in its icon name.

This is done in waybar rather than by disabling fcitx5's tray addon, which
would mean overriding how fcitx5 starts ([input method](../input-method.md)).

## KDE Connect

The phone module in the bar (`custom/kdeconnect`) is a script, because waybar
has no kdeconnect module of its own: `waybar/scripts/kdeconnect.sh`, polled
every 10s. It shows the paired phone's battery, dims when the phone is off the
network, and is not drawn at all until a phone is paired — so on a machine that
has never run `kdeconnect-cli --pair` the bar looks exactly as it did before.

| click | does |
| --- | --- |
| left | opens `kdeconnect-app` |
| middle | sends the clipboard to the phone |
| right | rings the phone |

It reads `charge` and `isCharging` straight off D-Bus with `gdbus`, since
`kdeconnect-cli` can pair and list devices but cannot report a battery. `gdbus`
rather than `qdbus` because it comes from glib2, already pulled in by waybar,
where qdbus would mean installing qt5-tools for two property reads.

The daemon is **not** in `hypr/autostart.lua`, [like fcitx5](../input-method.md):
`kdeconnectd` ships `/etc/xdg/autostart/org.kde.kdeconnect.daemon.desktop`,
which uwsm starts, and it is D-Bus activatable besides. The script checks the
bus name has an owner rather than calling into it blind, so a machine where the
daemon has been stopped on purpose does not get one started by its status bar.

Pairing is one command per device, phone app open on the same network:

```bash
kdeconnect-cli --refresh && kdeconnect-cli --list-available
kdeconnect-cli --pair -d <device-id>
```


## Privacy indicators

`custom/privacy` (`scripts/privacy.sh`, every 2s) draws one Nerd Font icon per
thing capturing, coloured like macOS's dots, and nothing at all otherwise. When
one comes on, the pill pulses in its colour for about 4s; the script keeps
the last state in `$XDG_RUNTIME_DIR/waybar-privacy` to tell.

| icon | lights for | source |
| --- | --- | --- |
| green camera | any process holding `/dev/video*` | `/proc/*/fd` |
| orange mic | running mic recordings, not level meters | PipeWire `Stream/Input/Audio` |
| purple screen | portal screencasts, and cameras opened through PipeWire | PipeWire `Stream/Input/Video` |

Not waybar's own `privacy` module: it draws GTK theme icons, which can't be
Nerd Font glyphs, and only sees PipeWire. Most apps (Chromium, Zoom, OBS) open
the webcam straight through V4L2, where PipeWire never sees it. Tools that use
Hyprland's screencopy protocol directly (`grim`, `wf-recorder`) bypass PipeWire
too, and nothing here catches them.
