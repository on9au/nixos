# GTK, not KDE

The desktop apps are GTK: Nautilus, Papers (PDF), Loupe (images), seahorse
(keyring and the askpass helper), and the GTK portal for file and "Open With"
dialogs. The theme is `catppuccin-gtk` (Mocha, mauve accent) in
`../catppuccin/home.nix`, imported into `gtk-4.0/gtk.css` for libadwaita apps, with
`color-scheme = prefer-dark` alongside.

The only Qt apps left are KDE Connect and fcitx5's config tool. They follow
the GTK theme through `QT_QPA_PLATFORMTHEME=gtk3` in `uwsm/env`. **Never set it
to `kde`**: outside Plasma that breaks opening files, with KIO showing an "Open
With" dialog that lists nothing.

File associations live in `mimeapps.list` (tracked). Images had no entry at
all, so they fell through to whatever the system mimeinfo cache picked —
Brave. They are pinned to Loupe now:

```bash
xdg-mime query default image/png
```

