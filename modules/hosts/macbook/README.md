# MBP-DYLAN (macOS)

- `SOC:` Apple M5
- `RAM`: 16GB
- `SSD`: 1TB

This also runs on a 14" MacBook Pro (M5, macOS 26). There is no
Wayland here, so none of it is a literal port — it is the closest analog stack
macOS has, config for config:

| Linux / Hyprland | macOS | config |
| --- | --- | --- |
| Hyprland | AeroSpace | `.config/aerospace` |
| waybar | SketchyBar | `.config/sketchybar` |
| `looknfeel.lua` borders | JankyBorders | `.config/borders` |
| kitty | Ghostty | `.config/ghostty` |
| `kb_options` in `input.lua` | Karabiner-Elements | `.config/karabiner` |
| `repeat_rate` / `repeat_delay` | `KeyRepeat` / `InitialKeyRepeat` | `system/darwin/defaults.nix` |

Ghostty rather than kitty for one reason: **background blur.** kitty's blur is
Wayland-only (wlroots/KWin) and is a silent no-op on macOS; Ghostty implements
it through `NSVisualEffectView`. Linux keeps kitty.

## Bring-up

Install [Nix](https://nixos.org/download) and [Homebrew](https://brew.sh) —
nix-darwin drives brew but does not install it — clone this repo to `~/nixos`,
then:

```bash
sudo nix run nix-darwin -- switch --flake ~/nixos#MBP-DYLAN
```

The casks and the SketchyBar/borders formulae are declared by the
`programs/macos/*` modules; everything else comes from nixpkgs.

**sketchybar, borders and aerospace are in third-party taps**, and Homebrew 6
refuses to load a third-party formula until its tap is trusted — the whole
bundle aborts with "Refusing to load formula … from untrusted tap". The taps
are marked `trusted = true` for that reason.

Raycast needs three things set by hand after install, none of them scriptable
(its settings live in a private store, not a plist worth writing):

- **Hotkey: press physical Command + Space into its recorder.** The launcher
  is `ALT + Space` on Linux (`binds.lua`), and the key in Alt's position on a
  Mac is Command — the same positional argument as the symbolic hotkeys in
  `modules/system/darwin/defaults.nix`.
  Under the Ctrl<->Cmd swap that reaches Raycast as `Ctrl+Space`, which is
  what its recorder will show; that is correct, not a misread.
- **Disable its Window Management extension.** It does AeroSpace's job, and
  two window managers issuing move/resize at the same windows fight. AeroSpace
  is the one wired into the workspaces and SketchyBar.
- Raycast asks for Accessibility on first launch, separately from AeroSpace's
  grant.

`Ctrl+Space` is only free because `system/darwin/defaults.nix` moves symbolic hotkey
60 ("Select the previous input source") off it. Stock macOS has the input
switcher there, which is why Command+Space opens the language menu on a fresh
machine with the swap in place. Spotlight still answers on physical
Ctrl+Space, which emits `Cmd+Space`; Raycast supersedes it, and its onboarding
offers to turn it off.

`tree-sitter` in `programs/development/neovim/home.nix` is the CLI, not the library neovim links —
nvim-treesitter needs it and `:checkhealth` fails without it.

`imagemagick`, `ghostscript` and `tectonic` are Snacks.image's rendering
chain (raster, PDF, LaTeX). `lazygit` backs `Snacks.lazygit`.

## Keyboard

The point of this section is to type on a Mac the way you type on Linux.
Karabiner does all of it; `programs/macos/karabiner/config/README.md` carries the full
reasoning, including what each rule costs.

| held / tapped | does | replaces |
| --- | --- | --- |
| **Left Option** | hyper (`ctrl+opt+cmd`) — the AeroSpace mod | `SUPER` |
| **Caps Lock** | held: Ctrl. Tapped: Escape | nothing — Linux leaves `kb_options` empty |
| **Control** | Command, everywhere except terminals | — |
| **Globe / Fn** | cycles input source (AU / Chinese / Japanese) | — |
| **L-Opt + Space** | previous input source | `SUPER+Space` (fcitx5) |
| **Cmd + Space** | Raycast launcher | `ALT+Space` (fuzzel) |
| **Cmd / Ctrl + Tab** | next tab — the app switcher is removed | `Ctrl+Tab` |
| **Ctrl + arrows** | move by word (and `+Shift` selects) | `Ctrl+arrows` |
| **Cmd + arrows** | line / document jumps, as on a stock Mac | `Home` / `End` |

**Left Option is the modifier because muscle memory is positional.** The
bottom rows do not line up:

```
PC/Linux:  [Ctrl] [Super] [Alt ] [Space]
Mac:       [Ctrl] [Opt  ] [Cmd ] [Space]
                    ^
       the key where SUPER lives is Option
```

So `SUPER+H` on Linux and `L-Opt+H` here are the same physical motion, and
both mean `focus left`. Only the **left** Option is grabbed — right Option
still types `Opt+3` → `#` and still moves word-wise with the arrows.

**Control and Command are swapped** so `Ctrl+C`/`Ctrl+V`/`Ctrl+T`/`Ctrl+W`
work the way they do on every Linux desktop — *except in terminals*, which are
excluded by bundle ID so `Ctrl+C` stays SIGINT. Ghostty needs no help here:
`copy-on-select` and `ctrl+shift+v` already make it behave like a Linux
terminal.

Two knock-on effects worth knowing before you go hunting for a bug:

- macOS's own screenshot shortcuts move with the swap: **`Ctrl+Shift+3/4/5`**,
  not `Cmd+Shift+3/4/5`.
- Anything holding *both* Ctrl and Cmd is unaffected, because swapping the two
  maps the pair onto itself. That covers the emoji picker (`Ctrl+Cmd+Space`)
  and, more importantly, every `ctrl-alt-cmd-*` bind in `aerospace.toml`.

The swap lives in Karabiner rather than **System Settings → Keyboard →
Modifier Keys** purely for that terminal exclusion — the built-in panel is
global, with no per-app exemption.

None of the AeroSpace binds *require* Karabiner. They are plain
`ctrl-alt-cmd-*`, so physically holding Control+Option+Command reaches all of
them on a machine where the driver extension has not been approved yet.

## The bar has to match the display

`sketchybarrc`'s `height`, `notch_width` and `notch_display_height` are
measured from one specific panel. **They do not transfer between Macs** — this
config moved from a 15" Air to a 14" Pro and every one of the three was wrong:

| | 15" Air | 14" Pro |
| --- | --- | --- |
| screen | 1710×1107 pt | 1512×982 pt |
| safe-area top | 38 pt | 32 pt |
| notch width | 209 pt | 185 pt |

Symptoms of not re-measuring are a bar noticeably taller than the real menu
bar, and a notch mask wide enough to swallow items either side of the cutout.
Re-measure with:

```bash
swift - <<'EOF'
import AppKit
let s = NSScreen.main!
print("frame:", s.frame)
print("safeAreaInsets top:", s.safeAreaInsets.top)   // -> bar height
if let l = s.auxiliaryTopLeftArea, let r = s.auxiliaryTopRightArea {
    print("notch width:", r.minX - l.maxX)           // -> notch_width
}
EOF
```

`gaps.outer.top` in `aerospace.toml` does **not** need updating alongside it,
and must not have the bar height added to it. AeroSpace tiles inside
`NSScreen.visibleFrame`, which has already subtracted the strip the bar sits
in — adding it back double-counts. It is plain `12`, the same as the other
three edges, and it stayed correct across the 38 → 32 change.

The clock is deliberately not `position=center`: true screen centre falls
*inside* the notch's excluded range, so a centred item renders behind the
physical cutout and never appears at all.

## System defaults

The other half of a macOS setup does not live in files at all — Dock, Finder,
Mission Control and text substitution are preference domains, set by
`system.defaults` in `modules/system/darwin/defaults.nix`.

Three settings there are load-bearing rather than taste:

| setting | why |
| --- | --- |
| Dock `autohide` | AeroSpace tiles inside `visibleFrame`, from which a pinned Dock is subtracted just like the menu bar strip — pinned, it costs an edge of *every* workspace |
| `mru-spaces`, `workspaces-auto-swoosh`, `expose-group-apps` off | AeroSpace indexes workspaces and does its own switching; macOS reordering Spaces or switching on app activation fights it |
| `_HIHideMenuBar` | SketchyBar draws into the strip the native bar occupies, so hiding the real one makes it a replacement rather than a competitor for the same 32pt |

Two things there are worth knowing about because macOS's own defaults are
actively hostile:

- **Bottom-right is Quick Note out of the box.** macOS ships
  `wvous-br-corner = 14` enabled. With `focus-follows-mouse` on in
  `aerospace.toml` the pointer gets flung at corners constantly, so this fires
  by accident far more than it would on a stock Mac. Turned off, along with
  the other three — except top-right, which is set to Notification Centre
  because `_HIHideMenuBar` plus SketchyBar's `click_script`-less clock leaves
  "click the clock" without a target.
- **The text substitutions corrupt code.** Smart quotes break shell snippets
  and dash substitution turns `--flag` into an en dash. Same class of problem
  as `ApplePressAndHoldEnabled`: a default that assumes prose.

Scroll direction is deliberately left alone.

## YubiKey and SSH

Git is **not** affected by any of this — the remotes here are HTTPS and
authenticate through `osxkeychain`, which Apple's git already sets as the
system-wide `credential.helper`. There is no `~/.gitconfig` on this machine
and none is needed; the `credential.helper libsecret` line in the Linux
section above is Linux-only advice.

What does need work is SSH, because **Apple's OpenSSH cannot talk to a FIDO
token at all.** It advertises the key types, which makes the failure
confusing:

```
ssh -Q key | grep sk        → sk-ssh-ed25519@openssh.com   (looks fine)
ssh-keygen -K               → Cannot download keys without provider
```

There is no built-in provider and no middleware to point `SecurityKeyProvider`
at — Homebrew's `libfido2` does *not* ship OpenSSH's `libsk-libfido2.dylib`,
since that is built as part of OpenSSH rather than of libfido2.

nixpkgs' `openssh` (`hardware/peripherals/yubikey/home.nix`) is the fix. It is built against
`libfido2`, so it has the provider compiled in, the same arrangement as on
Linux via `ssh-sk-helper`. The difference is visible immediately:

```
/usr/bin/ssh-keygen -K                         Cannot download keys without provider
/etc/profiles/per-user/djpro/bin/ssh-keygen -K Enter PIN for authenticator: …
```

The home-manager profile is ahead of `/usr/bin` on PATH, so shells get the
working one with no further configuration. GUI applications launched outside a
shell do not, and will still get Apple's.

With one key plugged in, the resident credential comes down the same way as on
Linux:

```bash
cd ~/.ssh && ssh-keygen -K       # PIN, then touch
```

**The agent is a trap here, and it is the same trap as gcr-ssh-agent above.**
`SSH_AUTH_SOCK` points at a launchd-managed **Apple** `ssh-agent`, which has
no more FIDO support than Apple's `ssh` does. So `ssh-add -K` hands a resident
credential to an agent that can never sign with it — and per the Linux notes,
an agent that holds an identity shadows the handle file on disk, so this
fails in the confusing direction.

Simplest answer is not to use an agent: with the handle files present, ssh
uses them directly and asks for a touch per connection. If the touches get
annoying, run nixpkgs' agent instead of Apple's and point `SSH_AUTH_SOCK`
at it — the macOS equivalent of swapping gcr for OpenSSH's agent on Linux.

Note `ssh-add -K` means two different things depending on which binary wins:
"download resident keys" in nixpkgs', and the legacy
"store passphrase in the Keychain" in Apple's (now spelled
`--apple-use-keychain`).

## Permissions that cannot be scripted

A switch does everything else, but three things need a human:

1. **AeroSpace** — Accessibility, on first launch. Without it the WM starts
   and does nothing at all.
2. **Karabiner** — an admin password at install, then the driver extension
   under *General → Login Items & Extensions → Driver Extensions*, plus Input
   Monitoring for `Karabiner-Elements` and `karabiner_grabber`.
3. **Log out and back in** after the first switch, so the `NSGlobalDomain`
   values reach apps that were already running.

Key repeat is the macOS half of `input.lua`'s `repeat_rate`/`repeat_delay`.
Its units are 15 ms ticks, not milliseconds, so the Linux numbers do not
transfer literally. The
piece that matters most is `ApplePressAndHoldEnabled = false`: left at its
default, holding a key pops the accent picker instead of repeating, so held
`hjkl` in nvim does nothing.

## Not ported

Dropped because macOS has no equivalent to port *to*, not by oversight:
hypridle/hyprlock (`CGSession -suspend` is a straight lock, with no idle
daemon to tell), the power menu, swaync, fcitx5, `power-profiles-daemon`,
temperature (no stable sensor path), and SketchyBar's missing systray — which
is also why Steam is absent from `aerospace/autostart.sh` where it exists in
`hosts/desktop/autostart.lua`, having been tray-only there.

AeroSpace has no equivalent for centring a floating window, pinning above
workspaces, pseudo-tiling, the scratchpad, or scroll-to-switch-workspace.
`resize smart ±60` is an approximation of `binds.lua`'s per-direction resize —
AeroSpace resizes by dimension, not by direction.

`norg` is a permanent `:checkhealth` warning, not a local misconfiguration:
nvim-treesitter has no parser registered under that name, so Snacks' hardcoded
check list can only ever warn.
