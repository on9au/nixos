# MBP-DYLAN (macOS)

- `SOC:` Apple M5
- `RAM`: 16GB
- `SSD`: 1TB

A 14" MacBook Pro on nix-darwin. There is no Wayland here, so each piece of the
Linux desktop has its closest macOS analog:

| Linux / Hyprland | macOS | module |
| --- | --- | --- |
| Hyprland | AeroSpace | [`programs/macos/aerospace`](../../programs/macos/aerospace) |
| waybar | SketchyBar | [`programs/macos/sketchybar`](../../programs/macos/sketchybar) |
| `looknfeel.lua` borders | JankyBorders | [`programs/macos/borders`](../../programs/macos/borders) |
| kitty | Ghostty, for background blur, which kitty only does on Wayland | [`programs/macos/ghostty`](../../programs/macos/ghostty) |
| `kb_options` in `input.lua` | Karabiner-Elements | [`programs/macos/karabiner`](../../programs/macos/karabiner/config/README.md) |
| key repeat, input switching | `system.defaults` | [`system/darwin/defaults.nix`](../../system/darwin/defaults.nix) |

Not ported, because macOS has nothing to port them to: hypridle/hyprlock, the
power menu, swaync, fcitx5, `power-profiles-daemon`, and the tray, which is why
Steam isn't in `aerospace/config/autostart.sh`.

## Bring-up

Install [Nix](https://nixos.org/download) and [Homebrew](https://brew.sh)
(nix-darwin drives brew but doesn't install it), clone this repo to `~/nixos`,
then:

```bash
sudo nix run nix-darwin -- switch --flake ~/nixos#MBP-DYLAN
```

Afterwards it's `nh darwin switch`. What a switch can't do:

1. **AeroSpace**: grant Accessibility on first launch, or it runs and does
   nothing.
2. **Karabiner**: an admin password and two approvals;
   [its README](../../programs/macos/karabiner/config/README.md#setup-that-cant-be-scripted)
   has them and a checklist to test with.
3. **Log out and back in**, so `NSGlobalDomain` values reach apps that were
   already running.
4. **Raycast**, whose settings aren't a plist worth writing:
   - Hotkey: press **physical Command + Space** into its recorder. It shows
     `Ctrl+Space` because of the Ctrl↔Cmd swap; that's right. (`defaults.nix`
     moves macOS's input-source hotkey off `Ctrl+Space` to free it.)
   - Disable its Window Management extension, which fights AeroSpace.
   - Grant it Accessibility too.

## Keyboard

Karabiner makes the Mac type like the Linux machines;
[its README](../../programs/macos/karabiner/config/README.md) has the
reasoning for each rule.

| held / tapped | does | replaces |
| --- | --- | --- |
| **Left Option** | hyper (`ctrl+opt+cmd`), the AeroSpace mod | `SUPER` |
| **Caps Lock** | held: Ctrl. Tapped: Escape | nothing; Linux leaves `kb_options` empty |
| **Control** | Command, everywhere except terminals | — |
| **Globe / Fn** | cycles input source | — |
| **L-Opt + Space** | previous input source | `SUPER+Space` (fcitx5) |
| **Cmd + Space** | Raycast | `ALT+Space` (fuzzel) |
| **Cmd / Ctrl + Tab** | next tab; the app switcher is removed | `Ctrl+Tab` |
| **Ctrl + arrows** | move by word | `Ctrl+arrows` |
| **Cmd + arrows** | line / document jumps | `Home` / `End` |

macOS's screenshot shortcuts move with the swap: **`Ctrl+Shift+3/4/5`**.

## On a different Mac: re-measure the bar

`height`, `notch_width` and `notch_display_height` in `sketchybarrc` come from
this panel and don't transfer. A wrong value shows as a bar taller than the
menu bar, or a notch mask that swallows the items beside it:

```bash
swift - <<'EOF'
import AppKit
let s = NSScreen.main!
print("safeAreaInsets top:", s.safeAreaInsets.top)   // -> height, notch_display_height
if let l = s.auxiliaryTopLeftArea, let r = s.auxiliaryTopRightArea {
    print("notch width:", r.minX - l.maxX)           // -> notch_width
}
EOF
```

`gaps.outer.top` in `aerospace.toml` stays as it is.

## YubiKey and SSH

Apple's OpenSSH can't use a FIDO2 key, though `ssh -Q key` lists the `sk`
types: `ssh-keygen -K` says *Cannot download keys without provider*.
nixpkgs' `openssh` (`hardware/peripherals/yubikey/home.nix`) can, and the
home-manager profile is ahead of `/usr/bin` on PATH, so shells get it. Apps
launched outside a shell still get Apple's. Git is unaffected: its remotes are
HTTPS through `osxkeychain`.

**Don't `ssh-add -K`.** `SSH_AUTH_SOCK` is Apple's launchd agent, which can't
sign with a FIDO2 key, and an identity in the agent shadows the handle file.
In Apple's binary `-K` means something else anyway (the old spelling of
`--apple-use-keychain`).

sshd is the shared policy on 7456 ([`system/darwin/sshd.nix`](../../system/darwin/sshd.nix));
launchd binds the port on every interface, so the LAN reaches it too. If a
shell over ssh can't read `~/Documents`, give
`/usr/libexec/sshd-keygen-wrapper` Full Disk Access.

```bash
sudo launchctl print system/org.nixos.sshd | grep state
nc -z localhost 7456 && echo listening
```
