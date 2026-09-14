# Login manager (greetd + ReGreet)

`services.greetd` and `services.displayManager.regreet` in
[`default.nix`](default.nix).

ReGreet is a GTK app, so it needs a compositor. greetd runs it inside
**Hyprland**, using [`hyprland.lua`](hyprland.lua).

Not cage: cage cannot describe monitors. It either extends across every output
(the default) or uses whichever connected last. Extending builds one ~7680px
output space across both 4K panels, so the prompt lands across the bezel seam
and the background is stretched over both screens. Hyprland gives the greeter
the same modes, scales and positions as the session — **keep those monitor
lines in sync with `hypr/monitors.lua`.**

The greeter config is **Lua**, like the session's. A `.conf` works, but
Hyprland calls it "legacy config" and says so on screen — a deprecation warning
sitting over the login prompt. The `hyprland.start` handler runs
`regreet; hyprctl dispatch "hl.dsp.exit()"`, tearing the compositor down the
moment the greeter finishes (note the Lua dispatch form — the classic syntax
would be a parse error here too).

The greeter's `hyprland.lua` carries every machine's monitor block at once. It
does not need to be per-host: a block for an output that is not plugged in is
inert, so the desktop ignores the panel's block and the laptop ignores the
AOC's.

The `DP-*` lines are the exception, and they are why **the ultrawide's block
has to stay above them.** Rules match in declaration order, first hit wins.
The laptop's external display arrives over USB-C on some unpredictable `DP-*`
connector, and `DP-1` — which this file *disables* to pin the desktop's prompt
to the AOC — is as likely as any. Claiming it by description first is what
stops the greeter blanking it. The old comment there claimed "there is no DP-1
on the laptop"; that stopped being true the day the laptop got a monitor.

On the laptop both screens are left lit at the greeter, so which one the prompt
opens on is down to enumeration order. Disabling the panel the way `DP-1` is
disabled would also disable it when the laptop is on its own, leaving nothing
to log in on.

On the desktop the prompt is pinned to the **32" AOC by disabling `DP-1` for
the login screen** — so the Dell is dark for the few seconds the greeter is up.

That is blunt on purpose. Hyprland enumerates `DP-1` first (monitor ID 0), so
it takes focus at startup and the greeter opened there.
`cursor.default_monitor = "DP-2"` and a `monitor = "DP-2"` window rule both
failed to move it, and a greeter cannot be iterated on quickly — every attempt
costs a logout. One output cannot be got wrong.

To light both instead, give `DP-1` the mode/position/scale from
`hypr/monitors.lua` in place of `disabled`, and expect to have to solve the
focus problem.

A greeter is not a session, so several of Hyprland's on-screen notices are
turned off in `misc` — otherwise they stack up over the login prompt:

| option | silences |
| --- | --- |
| `disable_xdg_env_checks` | "launched directly" — greetd starts it without a session manager's `XDG_*` vars |
| `disable_scale_notification` | the fractional-scaling notice |
| `disable_hyprland_guiutils_check`, `disable_watchdog_warning` | qtutils / watchdog nags |
| `ecosystem.no_update_news`, `no_donation_nag` | update news and donation popups |

**The greeter runs as the `greeter` user and cannot read `/home/djpro`** (mode
`700`), so nothing it shows can live there. The wallpaper is
`desktop.greeterWallpaper`, a file in `hosts/<host>/`, and the cursor theme is
installed system-wide by `regreet.cursorTheme`.

Sudo prompts outside a terminal (GUI apps, launcher scripts) go through
`SUDO_ASKPASS`, set in `uwsm/env` — which resolves the first helper it can find
out of `ssh-askpass`, `ksshaskpass` and `lxqt-openssh-askpass`, rather than
naming a path. `programs/services/ssh-agent` puts seahorse's GTK helper on PATH
as `ssh-askpass`.

Pick **"Hyprland (uwsm)"** in the session list, not plain "Hyprland" — see
below. `Ctrl`+`Alt`+`F2` reaches a text login if the greeter ever fails to
start; booting the previous generation is the other way back.

## Logging in

Pick **"Hyprland (uwsm)"** at the greeter, not plain "Hyprland". uwsm runs the
session as a proper systemd user session, so `graphical-session.target` works
and everything autostarted gets its own unit you can poke at:

```bash
systemctl --user status waybar
```

