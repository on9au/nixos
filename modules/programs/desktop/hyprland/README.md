# Hyprland

The session's tools are in [`home.nix`](home.nix). The rest of the desktop is
split across `programs/desktop`, `programs/services` and `hardware`; a host's
`default.nix` lists what it uses.

`playerctl` drives the media keys, `pavucontrol` and `nmtui` are what the
waybar audio/network modules open on click, and `htop` is what the cpu/memory
modules open. `brightnessctl` is the laptop's backlight keys and hypridle's
dim-before-lock; `power-profiles-daemon` backs the waybar power profile
switcher. `wtype` and `noto-fonts-color-emoji` are for the emoji picker —
without the font the picker lists tofu boxes.

## Two machines

This runs on a two-monitor desktop and on a laptop (`LAPTOP-ON9AU`, a
16" Dell with one 3840x2400 panel and hybrid Intel/NVIDIA graphics). The
settings that genuinely differ live in `hypr/hosts/<host>/`, one file per
topic, and `hypr/host.lua` picks the directory from the hostname. Everything
else is shared.

| topic | what differs |
| --- | --- |
| `monitors.lua` | three outputs vs one; fractional vs integer scale |
| `input.lua` | mouse feel vs touchpad; numlock |
| `binds.lua` | focus-a-monitor keys vs backlight keys |
| `rules.lua` | 10 workspaces pinned across two screens vs 5 on one |
| `apps.lua` | wallpaper (16:9 vs 16:10) |
| `autostart.lua` | which applications start, and where |

An unrecognised hostname falls through to `hosts/desktop/`. Adding a third
machine is a new directory plus one entry in `host.lua`.

`uwsm/env` has a per-hostname block for the same reason — see **Hybrid
graphics** below.

## Layout

Hyprland 0.56 uses a Lua config. It is split by topic instead of living in one
12KB file:

| file | what's in it |
| --- | --- |
| `hypr/hyprland.lua` | entry point, just `require`s the rest |
| `hypr/host.lua` | which machine this is, from the hostname |
| `hypr/hosts/<host>/` | the per-machine half of the files below |
| `hypr/colors.lua` | Catppuccin Mocha palette |
| `hypr/apps.lua` | default terminal / browser / launcher / wallpaper |
| `hypr/monitors.lua` | resolution, refresh rate, scaling, placement |
| `hypr/env.lua` | Wayland toolkit + cursor env vars |
| `hypr/looknfeel.lua` | gaps, borders, blur, animations |
| `hypr/input.lua` | keyboard and mouse |
| `hypr/binds.lua` | keybindings |
| `hypr/rules.lua` | window / workspace / layer rules |
| `hypr/autostart.lua` | what starts with the session |
| `hypr/launch.lua` | the `uwsm app` helpers autostart uses, plus `launch.unit` |

`hyprlock.conf` and `hypridle.conf` sit in the same folder but are **hyprlang**,
not Lua — they belong to separate programs that kept the old format.

Check a config edit before logging out and finding out the hard way:

```bash
Hyprland --verify-config
```

The authoritative Lua API for the installed version is
`/run/current-system/sw/share/hypr/stubs/hl.meta.lua` — worth reading, the
wiki lags it.

## Monitors

Desktop (`hosts/desktop/monitors.lua`):

| output | monitor | mode | scale | position |
| --- | --- | --- | --- | --- |
| `DP-2` | AOC U32G4, 32" | 3840x2160@160 | 1.25 | left, primary |
| `DP-1` | Dell U2725QE, 27" | 3840x2160@120 | 1.5 | right |

Both panels advertise **3840x2160@60 as their preferred mode**, so
`mode = "preferred"` silently caps them at 60Hz. The modes are named explicitly
for that reason — don't "simplify" them back.

Scales are chosen so text is the same physical size on both (the 27" is denser)
and so both divide 3840 evenly. Workspaces 1–5 are pinned to the AOC, 6–10 to
the Dell.

Laptop (`hosts/LAPTOP-ON9AU/monitors.lua`):

| output | monitor | mode | scale | position |
| --- | --- | --- | --- | --- |
| `desc:Samsung…` | built-in 16" panel | 3840x2400@120 | 2 | `0x0` |
| `desc:Dell Inc. DELL U40` | Dell U4025QW, 40" ultrawide | `maxwidth` → 5120x2160@120 | 1.25 | `1920x-528` |

Both matched **by EDID description, not by connector name.** The panel comes up
as `eDP-1` or `eDP-2` depending on the boot: `simpledrm` holds a DRM minor from
the EFI framebuffer until a real driver displaces it, and which of i915/nvidia
lands where depends on init timing — the same hardware answered to `eDP-2` on
kernel 7.1.6 and `eDP-1` on 7.1.8. The ultrawide arrives over USB-C and gets
whichever `DP-*` is going. Get the description strings from
`hyprctl monitors all`.

Panel scale is an integer 2 (1920x1200 logical) — at ~283 DPI, taking
fractional-scaling blur would buy nothing. The ultrawide is ~140 DPI, the same
density as the desktop's 32" AOC, so it gets the same 1.25 → 4096x1728, both
axes exact. The panel keeps the origin and the ultrawide is offset around it
rather than the other way round, so pulling the cable changes nothing about the
undocked layout.

`1920x-528` places it **to the right of the panel with their bottom edges
flush**, matching the desk: the laptop sits beside the monitor on its left, and
low, because a laptop screen starts at desk level. `x = 1920` is the panel's
logical width, so the two touch with no gap; `y = 1200 - 1728 = -528` lines the
bottoms up. Bottom-flush is deliberate — it makes the panel's y range a subset
of the ultrawide's, so every row of the panel has somewhere to go and the
cursor never sticks at the seam.

**`desc:` is a prefix match**, not a glob. `desc:Dell Inc. DELL U40` therefore
covers the whole Dell 40" 5K2K family (U4021QW / U4023QW / U4025QW) in one
block — they are all 5120x2160 across ~39.7", so one scale fits all of them.

### Why `maxwidth` and not `highres`

These are shared work monitors: some of the 40" ultrawides here cap at 60Hz and
some do 120Hz, so a hardcoded mode is a modeset failure on half of them. Of the
three keywords, only `maxwidth` sorts this panel shape correctly:

| keyword | comparator | result |
| --- | --- | --- |
| `highres` | `a.x > b.x && a.y > b.y` | **broken here.** 5120x2160 vs 3840x2160 fails on `2160 > 2160`, and the equal-resolution tiebreak also needs `x` within 1px. Every 2160-tall mode is mutually incomparable, and the sort is unstable → arbitrary width. |
| `highrr` | refresh first, resolution only breaks an exact tie | one fleet monitor offering 1920x1080@144 wins outright over 5120x2160@120 ([#9209](https://github.com/hyprwm/Hyprland/issues/9209)) |
| `maxwidth` | `a.x > b.x`, ties by higher refresh | widest mode, then fastest at that width. What we want. |

Hyprland keeps the best 3 modes **plus** the preferred one as a fallback chain,
so a 60Hz sibling lands on 5120x2160@60 by itself and a failed modeset walks
120 → 100 → 75 → 60 rather than going dark.

That fallback matters: 5120x2160@120 is ~1485 MHz of pixel clock, ~35.6 Gbit/s,
which is more than DP 1.4 HBR3 carries (25.92) — **120Hz only exists with DSC.**
It works over this cable under Windows, so the link and the Arc iGPU can both
do it, but it is the first thing to suspect if the session comes up at 60. Note
also that the monitor's own USB-C setting can halve the lane count to keep USB 3
data speed.

Workspaces **1–5 are pinned to the ultrawide, 6–10 to the panel**, same split as
the desktop. Only 1–5 are persistent — ten permanently-lit numbers is most of a
16" waybar gone to workspaces nobody opened, and undocked the 16" bar is the
only bar there is. A workspace bound to an absent monitor opens on whatever is
present, so undocked you get all ten on the panel and in clamshell all ten on
the ultrawide, with no extra configuration.

### Clamshell

Closing the lid with the external display attached disables the built-in panel;
opening it brings it back. Closing it with nothing else attached suspends
instead. Two halves:

| where | what it does |
| --- | --- |
| `hypr/hosts/LAPTOP-ON9AU/binds.lua` | `switch:on:Lid Switch` → disable the panel, but only if `#hl.get_monitors() > 1` |
| `modules/hardware/power/laptop.nix` | `HandleLidSwitchDocked = "ignore"` so logind does not suspend out from under it |

logind counts "docked" as *in a dock **or** more than one display connected*,
which is the same condition as the Hyprland-side guard — the two agree by
construction. The other two `HandleLidSwitch*` settings are left at `suspend`.

Calling `hl.monitor()` at runtime **merges** into the existing rule for that
output name and schedules a re-apply, so flipping `disabled` keeps the panel's
mode/position/scale — no `hyprctl` shell-out, and nothing restated.

`SW_LID` reads 1 when the lid is *closed*, hence `switch:on` being the close
event. The device name is libinput's, not guaranteed — check with
`hyprctl devices | grep -i switch`.

## Keys

`SUPER` is the modifier. Full list at runtime: `hyprctl binds`.

| bind | does |
| --- | --- |
| `SUPER` + `Return` | terminal |
| `Alt` + `Space` | app launcher |
| `SUPER` + `Space` | switch input method (fcitx5, not Hyprland) |
| `SUPER` + `E` / `B` | file manager / browser |
| `SUPER` + `Q` | close window |
| `SUPER` + `hjkl` or arrows | move focus |
| `SUPER` + `Shift` + `hjkl` | move window |
| `SUPER` + `Ctrl` + `hjkl` | resize window |
| `SUPER` + `1`–`0` | switch workspace |
| `SUPER` + `Shift` + `1`–`0` | send window to workspace |
| `SUPER` + `,` / `.` | focus left / right monitor (**desktop only**) |
| `SUPER` + `V` | toggle floating |
| `SUPER` + `F` / `Shift` + `F` | fullscreen / maximize |
| `SUPER` + `T` | flip split direction |
| `SUPER` + `S` | scratchpad |
| `SUPER` + `Shift` + `V` | clipboard history |
| `SUPER` + `Shift` + `E` | emoji picker |
| `SUPER` + `N` | notification centre |
| `SUPER` + `Escape` | lock |
| `SUPER` + `Shift` + `M` | power menu (lock / log out / suspend / reboot / shut down) |
| `Print` / `Shift`+`Print` / `Alt`+`Print` | screenshot region / monitor / window |
| `SUPER` + `C` / `Shift` + `C` | pick a colour on screen, as hex / rgb |

Laptop-only, from `hosts/LAPTOP-ON9AU/binds.lua`:

| bind | does |
| --- | --- |
| `XF86MonBrightnessUp` / `Down` | panel backlight, 5% steps |
| `XF86KbdBrightnessUp` / `Down` | keyboard backlight, one of three levels |

Both call `brightnessctl` with an explicit `-d`. That is not tidiness: this
laptop has **two** devices in `/sys/class/backlight` — `intel_backlight` (the
panel) and `nvidia_0` (the discrete GPU, which has no display wired to it) —
and `brightnessctl` with no `-d` picks `nvidia_0`, reports a plausible
percentage and changes nothing you can see. The waybar `backlight` module has
the same trap and the same fix.

These follow i3/sway convention, which is **not** what Hyprland ships:
upstream puts the terminal on `SUPER`+`Q` and close on `SUPER`+`C`. Lock is on
`Escape` rather than the usual `SUPER`+`L` because `L` is taken by hjkl focus.

## The Lua config gotcha

Worth knowing before debugging anything that talks to Hyprland: because the
config is Lua, **`hyprctl dispatch` evaluates its argument as Lua**, and the
classic syntax that every guide and third-party tool uses is a parse error.

```bash
hyprctl dispatch workspace 3                    # error: ')' expected near '3'
hyprctl dispatch 'hl.dsp.focus({workspace = 3})' # ok
```

This bites any program that shells out to `hyprctl dispatch` with the old
syntax, and it is why **waybar is built from git HEAD instead of the 0.15.0
release** — the `waybar` flake input, built with nixpkgs' recipe in
`programs/desktop/waybar/home.nix`; `nix flake update waybar` moves it to the latest commit. Release builds send `dispatch workspace
name:<n>` when you click a workspace, which is a parse error here, so clicking
did nothing at all. Master detects a Lua config and emits
`hl.dsp.focus({ workspace = "..." })` instead. Dropping the override for the
release build silently loses workspace clicking again — until a release
includes that change.

A `~/.local/bin/hyprctl` shim translating the old syntax was tried and
deliberately removed — shadowing a system binary for the whole graphical
session was a worse problem than the one it solved. Upstream fixing it was the
better outcome.

If some other tool or a snippet from the wiki appears to do nothing, run its
command by hand: a Lua parse error is the giveaway, and the fix is to rewrite
it as `hl.dsp.*`. The dispatcher names are all in
`/run/current-system/sw/share/hypr/stubs/hl.meta.lua`.

## Icons

Use only **Plane-15** Nerd Font glyphs (U+F0000 and above, the Material Design
range). Icons from the Basic Multilingual Plane private use area
(U+E000–U+F8FF) do not survive being written into these files and silently
become empty strings — which is what emptied the power menu, thermometer, wifi
and launcher-prompt icons.

The installed FiraCode Nerd Font covers `f000-f381` and `f0001-f1af0`; check
before picking a glyph:

```bash
fc-query --format='%{charset}\n' "$(fc-match -f '%{file}' 'FiraCode Nerd Font')"
```

## Notification centre has no volume slider

Deliberate. swaync 0.12.6's `volume` widget binds to a sink at startup and does
not follow the default-sink selection, so it showed and controlled the wrong
output. It is not a PipeWire mismatch — `pactl info` and `wpctl status` both
report the right default; swaync just ignores it.

There is no way to point it at a sink (only the `backlight` widget takes a
`device`), and `swaync-git` is *older* than the released 0.12.6, so there is
nothing to upgrade to. A slider that lies about the volume is worse than none.

Volume lives in waybar instead: scroll it to adjust, click for `pavucontrol`.
To try the widget again, put `"volume"` back in `widgets` in
`swaync/config.json`.

## What starts with the session

Defined in `hypr/autostart.lua`, not XDG autostart. The daemons — waybar,
swaync, hypridle, the polkit agent, the two cliphist watchers, the wallpaper —
are the same everywhere; the applications are per-machine and live in
`hosts/<host>/autostart.lua`:

| app | desktop | laptop |
| --- | --- | --- |
| kitty | 1 | 1 |
| firefox | 2 | 2 |
| discord | 6 | — |
| spotify | 7 | 5 |
| steam | tray only (`-silent`) | — (not installed) |

Placement uses the per-launch rule argument to `hl.exec_cmd`, **not** a
`window_rule` matching on class. A class rule would drag *every* future window
of that app to the workspace — so opening a second terminal would yank it to 1.
This way only the launched instance is placed. `silent` puts it there without
switching to it, so the session doesn't shuffle you around while it comes up.

The old `~/.config/autostart` entries for Discord and Steam are deleted on every
switch by `home.nix`: uwsm runs XDG autostart too, so leaving them there launches
each app twice. Both apps rewrite that file when their in-app "run on startup"
setting is toggled, so turn it off inside them as well if they reappear.

## Emoji picker

`SUPER`+`Shift`+`E` opens `~/.local/bin/emoji`, a wrapper around **bemoji**
that draws the list with fuzzel, so it inherits the same
theme, size and `Ctrl`+`j`/`k` navigation as the launcher. The pick is copied
to the clipboard *and* typed into the focused window.

Not on `SUPER`+`.`, which is what most desktops use: the desktop host spends
comma and period on focus-a-monitor, so that bind would work on the laptop and
be dead on the desktop.

bemoji has no config file — every knob is an environment variable, which is why
there is a script rather than a bare `hl.exec_cmd("bemoji")`:

| | |
| --- | --- |
| `BEMOJI_PICKER_CMD` | pinned to fuzzel. bemoji's own search order is bemenu → wofi → rofi → dmenu → wmenu → ilia → fuzzel, so it lands on fuzzel here only because none of the others are installed |
| `-c -t` | copy *and* type. Typing needs `wtype`; the script checks for it first, because bemoji would otherwise copy and then print "No suitable typing tool found" |
| `-n` | no trailing newline, so pasting doesn't also press Enter |

Inside the picker, `Alt`+`1` copies only and `Alt`+`2` types only. That is not
configured anywhere: fuzzel's `custom-1`/`custom-2` binds exit with codes 10
and 11, and those are exactly the codes bemoji reads as clip-only and
type-only.

First run downloads the Unicode emoji list to `~/.local/share/bemoji/`
(needs network, once). Picks are counted in
`~/.local/state/bemoji-history.txt` and float to the top of the list after
that. `bemoji -D nerd` adds the Nerd Font glyphs to the same database — the
terminal font here is a Nerd Font, so they render.

## Colour picker

`SUPER`+`C` picks a pixel anywhere on screen and puts it on the clipboard as
`#rrggbb`; `SUPER`+`Shift`+`C` does the same and writes `rgb(30, 30, 46)`
instead. The screen freezes while you aim, with a zoom lens under the cursor,
and the value comes back as a notification with a swatch of the colour.

The picking is **hyprpicker** (same authors as the compositor). `~/.local/bin/colorpicker` is the wrapper around it, and exists
for four small reasons — hyprpicker has both `--autocopy` and `--notify` built
in, and neither is quite right here:

| | |
| --- | --- |
| `-b` (no-fancy) | hyprpicker otherwise wraps its output in ANSI colour escapes. Readable in a terminal; from a keybind those bytes would land on the clipboard |
| own `wl-copy` | `--autocopy` appends a newline, so pasting into a config file also presses Enter. It would also copy hex when rgb was asked for |
| rgb | hyprpicker emits one format per run, so the pick is always taken as hex and converted afterwards. That is also what lets the swatch exist for both binds |
| swatch | the notification shows the colour, not just six characters of hex. Drawn with ImageMagick, with a `surface2` border so a colour near the notification's own background still has an edge. Optional — no ImageMagick, no picture, everything else still works |

Picks go through `wl-copy`, so cliphist stores them and old ones come back
under `SUPER`+`Shift`+`V`.

`-l` for lowercase hex, matching `colors.lua` and the stylesheets. `-r` freezes
the *inactive* displays too, so a hover state or a video on the other screen
holds still while you aim.

One thing to know if a pick ever looks a shade off: every external screen here
runs a fractional scale (1.25 on the 32" and the ultrawide, 1.5 on the 27"), so
a logical cursor position does not land on exactly one device pixel.
`hyprpicker -t` disables fractional-scale handling and is the first flag to try
if that shows up — add it to the `hyprpicker` line in the script. The laptop
panel is on scale 2 and cannot be affected.

## Session management

`SUPER`+`Shift`+`M` opens `~/.local/bin/powermenu`, a fuzzel menu with lock /
log out / suspend / reboot / shut down. fuzzel rather than wlogout so it
inherits the same theme and there is one less package to configure.

Log out runs **`uwsm stop`**, not `hyprctl dispatch exit`. The session is a
systemd unit under uwsm, so killing just the compositor leaves the rest of the
user session units running.

## Idle, locking and suspend

`hypr/hypridle.conf`, one file for both machines:

| after | happens |
| --- | --- |
| 2m30s | backlight dims to 10% (saved and restored, so it comes back where you left it) |
| 5m00s | `loginctl lock-session` → hyprlock |
| 5m30s | screen off (DPMS) |
| 15m00s | suspend — **on battery only** |

hypridle has no idea what host it is on, so "laptop only" is expressed as a
condition on the command instead. The suspend listener uses hypridle's own
`condition_cmd`, which runs at the timeout and fires the listener only if it
exits 0:

```
condition_cmd = grep -q '^0$' /sys/class/power_supply/AC/online
```

That is false whenever the charger is in, and on a desktop it is false always —
which preserves the desktop's original rule of never suspending, because it
runs docker and tailscale and sleeping drops both. The dim listener is
self-limiting in the same way: a machine with no backlight device just fails
the `brightnessctl` call harmlessly.

**Lid close is not hypridle.** It is split between logind and Hyprland — see
**Clamshell** under *Monitors*. The logind half is `services.logind.settings`
in `modules/hardware/power/laptop.nix`.

## HiDPI and XWayland

Wayland-native apps handle scaling themselves (1.25/1.5 on the desktop, 2 on
the laptop). X11 apps cannot, so `hypr/xwayland.lua` sets `force_zero_scaling`:
they get the panel's real pixel size and render sharp, instead of drawing at
logical size and being upscaled into a blurry mess.

The catch is that an X11 app then draws at 1:1 and looks small unless it scales
itself, so those need handling one at a time — Steam via
`STEAM_FORCE_DESKTOPUI_SCALING` in `uwsm/env`, which is set per machine to
match that machine's scale.

The better fix is always to get the app off XWayland entirely. Spotify was the
easy win: `programs/apps/spotify.nix` wraps it with the Ozone flags, since nixpkgs'
wrapper does not pass them. To see what is still on X11:

```bash
hyprctl clients -j | jq -r '.[] | select(.xwayland) | .class'
```

