# Waybar

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

**This used to be done at the source, and that was the wrong side of it.**
waybar had no ignore list when this was first set up, so the icon was
suppressed by forcing `--disable=notificationitem` into fcitx5 itself, through
two hand-written files that overrode the packaged ones:

| file | start path |
| --- | --- |
| `local/share/dbus-1/services/org.fcitx.Fcitx5.service` | D-Bus activation — the live one |
| `autostart/org.fcitx.Fcitx5.desktop` | XDG autostart |

Both are deleted. Both hardcoded `Exec=/usr/bin/fcitx5`, and because the D-Bus
one *overrides* the packaged service rather than adding to it, carrying it to a
machine that puts fcitx5 anywhere else would not have cost the tray icon — it
would have cost the input method, with the first app to ask for the
`org.fcitx.Fcitx5` name activating a binary that is not there. Deleting them
also hands input-method startup back to whatever packages it, which on NixOS is
`i18n.inputMethod`.

The findings underneath them still hold, if the addon ever needs switching off
for real. `Enabled=False` in `fcitx5/addon/notificationitem.conf` does nothing
— fcitx5 loads the addon anyway — and patching only the autostart entry does
nothing either, because fcitx5 is D-Bus activated:
`dbus-…-org.fcitx.Fcitx5@0.service` runs while
`app-org.fcitx.Fcitx5@autostart.service` sits *inactive*. Check which path is
live with:

```bash
systemctl --user list-units --all | grep -i fcitx
```

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

The daemon is **not** in `hypr/autostart.lua`, same reasoning as fcitx5 above:
`kdeconnectd` ships `/etc/xdg/autostart/org.kde.kdeconnect.daemon.desktop`,
which uwsm starts, and it is D-Bus activatable besides. The script checks the
bus name has an owner rather than calling into it blind, so a machine where the
daemon has been stopped on purpose does not get one started by its status bar.

Pairing is one command per device, phone app open on the same network:

```bash
kdeconnect-cli --refresh && kdeconnect-cli --list-available
kdeconnect-cli --pair -d <device-id>
```

