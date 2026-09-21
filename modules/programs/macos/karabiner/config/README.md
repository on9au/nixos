# Karabiner-Elements

Seven rules, all there to make a Mac keyboard behave like the Linux one this
repo is really built around. `karabiner.json` is JSON and can't hold comments,
hence this file.

| rule | what it does |
| --- | --- |
| **Left Option -> hyper** | held, sends `ctrl+opt+cmd` -- the single-key `SUPER` that drives AeroSpace |
| **Caps Lock** | held: Ctrl. Tapped: Escape, for nvim and `mode-keys vi` in `~/.tmux.conf` |
| **Ctrl <-> Cmd** | copy/paste/quit/tabs move to Control, like every Linux desktop. Terminals excluded |
| **Cmd+Space** | always reaches the launcher, in or out of a terminal -- see below |
| **Cmd+Tab** | no app switcher; Tab cycles tabs the Linux way |
| **Arrows** | Ctrl+arrow moves by word; Cmd+arrow keeps the macOS line/doc jumps |
| **Delete** | Ctrl+Delete deletes by word; Cmd+Delete keeps the macOS delete-to-line-start |

## Why Left Option is the modifier

Muscle memory is positional, not nominal. The bottom rows do not line up:

    PC/Linux:  [Ctrl] [Super] [Alt ] [Space]
    Mac:       [Ctrl] [Opt  ] [Cmd ] [Space]

The key sitting where `SUPER` lives on a PC is **Option**, so that is the one
mapped to hyper. Reaching for `SUPER+H` lands on the right physical key with
no retraining, and `../aerospace/aerospace.toml` binds it to `focus left` --
the same thing `../hypr/binds.lua` binds `SUPER+H` to.

The cost is real and worth stating: **left Option stops being a text
modifier.** macOS uses Option to type symbols (`Opt+3` -> `#`) and to move
word-wise with the arrows. Only the left key is grabbed, so **right Option
still does all of that** -- the loss is one of two keys, not the function.

Caps Lock held used to be the hyper key here, and both were briefly on offer.
Left Option won on position. Caps Lock kept the half that has nothing to do
with the window manager: tapped, it is Escape.

## Why hyper is ctrl+opt+cmd and not ctrl+opt+cmd+shift

The usual "hyper" recipe folds `shift` in too. That would be wrong here: the
Hyprland binds this mirrors use `SUPER` for focus and `SUPER+SHIFT` for move,
so `shift` has to stay free to act as the second half of the pair. Held Option
therefore sends three modifiers, not four, and `L-Opt+shift+h` cleanly reaches
AeroSpace's `ctrl-alt-cmd-shift-h`.

`ctrl+opt+cmd` is unclaimed on macOS. The near misses all drop one of the
three: Ctrl+Cmd+Space (emoji), Ctrl+Cmd+F (fullscreen), Cmd+Opt+Esc (force
quit). VoiceOver's VO key is Ctrl+Opt, but only while VoiceOver is running.

## Why the Ctrl/Cmd swap excludes terminals

Swapping the two everywhere would put `Ctrl+C` on the Command key -- and in a
terminal `Ctrl+C` is not "copy", it is SIGINT. Losing the interrupt to a
modifier swap is not a trade worth making, so every terminal emulator is
listed under `frontmost_application_unless` and keeps stock macOS behaviour:
`Ctrl+C` interrupts, `Cmd+C`/`Cmd+V` copy and paste.

`../ghostty/config` already covers the Linux terminal idiom on its own --
`copy-on-select = true` and `ctrl+shift+v` to paste, exactly as a Linux
terminal does -- so the exclusion costs nothing there.

This per-app carve-out is the whole reason the swap lives in Karabiner rather
than in **System Settings > Keyboard > Keyboard Shortcuts > Modifier Keys**.
That panel can swap Control and Command globally in two clicks, but it is all
or nothing, with no way to exempt an application.

Editors are deliberately *not* excluded. With the swap on, VS Code gets
`Ctrl+C`/`Ctrl+P`/`Ctrl+Shift+P`, which is its Linux keymap.

## The hole the terminal exclusion opens, and the patch

Excluding terminals is right for `Ctrl+C`, but it is an *app-wide* exclusion,
and that has a consequence worth stating plainly: **every chord behaves
differently inside a terminal than outside it.**

That is invisible for app shortcuts, which are per-app anyway. It is not
invisible for a global hotkey. The launcher is Command+Space, which outside a
terminal the swap turns into `Ctrl+Space` -- what Raycast listens for. Inside
Ghostty the swap is off, so the same press stays `Cmd+Space`, Raycast never
sees it, and Spotlight answers instead. The launcher silently stops working in
the one app you are most likely to launch things from.

Hence the fourth rule: in the same bundle list, and *only* for the spacebar
carrying Command, emit `Ctrl+Space` anyway. Nothing else about the terminal
exclusion changes -- `Ctrl+C` is not touched, because that rule matches
`spacebar` and nothing else.

Safe here because `Ctrl+Space` is unclaimed in this terminal stack: the tmux
prefix is `C-a` (`~/.tmux.conf`), nvim binds nothing to it, and ghostty's only
keybind is `ctrl+shift+v`. Check those three before adding a second chord to
this rule.

The general shape of the problem is worth remembering: **a global hotkey built
from a swapped modifier needs a rule like this one, or it dies in terminals.**
A chord holding both Ctrl and Cmd does not, being symmetric, and neither does
anything built on hyper, since that rule has no app condition at all.

## Which Ctrl Caps Lock sends

"Caps Lock is Ctrl" is ambiguous here, because rule 3 means there are two
Ctrls. Caps Lock sends **whichever one the physical Ctrl key would have
sent in the app you are in** -- so it is a better-placed duplicate of that
key, not a third behaviour to learn:

| in | Caps sends | so Caps+C is |
| --- | --- | --- |
| Orion, Finder, anywhere else | `command` | copy |
| Ghostty and the other terminals | `control` | SIGINT |

Which is the Linux arrangement in both places, and the same split rule 3
already makes. Two manipulators rather than one, on the same bundle list.

The alternative would be sending a literal `left_control` everywhere. That is
*not* what a Linux user means by the phrase: outside a terminal it would make
Caps+C a macOS Control+C, which almost nothing implements, so copy would
appear broken. It is a one-line change here if the genuine macOS Control is
ever wanted -- drop the second manipulator and remove the first's condition.

Karabiner does not re-process its own `to` output, so Caps Lock's `command`
is *not* then swapped back to Control by rule 3. That is what lets these two
rules coexist and why the app condition has to be repeated here rather than
inherited.

Tapped it is still Escape. `basic.to_if_alone_timeout_milliseconds` (200) is
the cutoff: press and release inside 200 ms for Escape, hold longer for Ctrl.

Two things fall out of Caps Lock now emitting a real `command` outside
terminals, and both are already handled:

- **Caps+Space** would have hit Spotlight rather than Raycast, since rule 4
  used to be terminal-only. It is unconditional now. Physical Cmd+Space is
  unaffected either way -- rule 3 turns that into `Ctrl+Space` before rule 4
  could see it.
- **Caps+Tab** is fine as-is: rule 5 was already unconditional, so it cycles
  tabs like everything else.

A pleasant accident in the terminal: the tmux prefix is `C-a`, so the prefix
is now Caps+A.

## Why Cmd+Tab is gone

Two reasons, and the second is the real one.

It is redundant: AeroSpace already switches windows on `L-Opt+hjkl` and
workspaces on `L-Opt+1..0`, across applications, so a separate
application-only switcher adds nothing.

More to the point, it was **stealing next-tab.** On both Linux and stock
macOS, cycling tabs in a browser is `Ctrl+Tab`. Under the swap, physical
Ctrl+Tab emits `Cmd+Tab`, so the app switcher grabbed it before Orion ever
saw it -- and the real `Ctrl+Tab` ended up on physical Cmd+Tab, which is not
somewhere anyone would think to look.

So this rule maps `Cmd+Tab` back to `Ctrl+Tab`. The result is that **both**
physical Ctrl+Tab and physical Cmd+Tab cycle tabs, and neither reaches the
app switcher, which is exactly the intent.

Deliberately unconditional, unlike rule 3. Terminals are exempt from the swap
but not from this: without the rule, Cmd+Tab would still summon the switcher
in Ghostty alone. Nothing in `~/.tmux.conf` or `ghostty/config` binds Tab, so
there is nothing there to collide with.

`L-Opt+Tab` is untouched -- it is AeroSpace's `workspace-back-and-forth`, and
it rides on hyper, whose rule has no app condition and no Command in it.

There is no supported `defaults` key for disabling the application switcher;
it lives in the Dock and WindowServer rather than in symbolichotkeys. A
Karabiner rule is the way to do it.

## Arrows: three claimants, one survivor

Before this rule, word-wise movement -- `Ctrl+Left` on Linux, and the single
most-used text motion there is -- had been squeezed out entirely:

| pressed | reached the app as | did |
| --- | --- | --- |
| `Ctrl+Left` | `Cmd+Left` (rule 3) | beginning of line |
| `Cmd+Left` | `Ctrl+Left` (rule 3) | Mission Control, move a space |
| `L-Opt+Left` | `ctrl+opt+cmd+Left` (rule 1) | AeroSpace `focus left` |
| `R-Opt+Left` | `Option+Left` | word left -- the only one |

So the motion existed, on the far side of the keyboard, reachable only with
the hand not doing the navigating.

This rule swaps the arrows back, and nothing is lost in the trade:

    Ctrl+arrow  ->  Option+arrow    word / paragraph moves    (Linux)
    Cmd+arrow   ->  Cmd+arrow       line and document jumps   (macOS, restored)

The first line is the point. The second is there because rule 3 had otherwise
left `Cmd+Left` meaning "move a space" -- so the macOS line-start and
document-start jumps had no chord at all, and this hands them back the one
they have on a stock Mac.

What actually goes is Mission Control's `Ctrl+arrow` space switching
(symbolic hotkeys 79-82). AeroSpace's workspaces replace Spaces wholesale and
`darwin-defaults.sh` already turns off `mru-spaces`, so there was nothing
there to lose.

Both directions carry `optional: ["shift"]`, so the selection variants follow
their movement counterparts: `Ctrl+Shift+Left` selects a word,
`Cmd+Shift+Left` selects to the start of the line.

Caps Lock comes along for free. Outside a terminal it emits `command`
(see above), so `Caps+Left` is a word left exactly as `Ctrl+Left` is --
which is the intent, Caps being a duplicate of Ctrl rather than its own thing.

**Terminals are excluded**, like rule 3. There, `Ctrl+Left` reaches Ghostty as
`Ctrl+Left` and becomes the escape sequence zsh and nvim expect -- the same
thing it would be on Linux. Rewriting it to `Option+Left` would break that for
no gain.

## Delete follows the arrows

Same problem as the arrows, same fix. Rule 3 had left the two erase chords on
keys nobody reaches for:

| pressed | reached the app as | did |
| --- | --- | --- |
| `Ctrl+Delete` | `Cmd+Delete` (rule 3) | delete to start of line |
| `Cmd+Delete` | `Ctrl+Delete` (rule 3) | nothing in most apps |
| `R-Opt+Delete` | `Option+Delete` | delete a word -- the only one |

So this rule swaps them back, exactly as rule 6 does for the arrows:

    Ctrl+Delete  ->  Option+Delete    delete the previous word   (Linux)
    Cmd+Delete   ->  Cmd+Delete       delete to start of line    (macOS, restored)

Caps Lock comes along for free for the same reason it does on the arrows:
outside a terminal it emits `command`, so `Caps+Delete` deletes a word.

Only `delete_or_backspace` is matched. Forward delete (`Fn+Delete`) is left
alone -- add a `delete_forward` pair here if the forward-word erase is ever
wanted.

**Terminals are excluded**, like rules 3 and 6: there `Ctrl+Delete` reaches
the terminal as itself, and zsh and nvim handle the erase.

## The swap does not disturb the window-manager binds

Two independent reasons, either one sufficient:

1. **The chord is symmetric.** `ctrl-alt-cmd` contains both swapped keys, so
   exchanging them maps the set onto itself. Whatever else changes,
   `{ctrl, opt, cmd}` is still `{ctrl, opt, cmd}`.
2. **Karabiner does not re-process its own output.** Events a manipulator
   emits in `to` go to the virtual keyboard, not back through the
   complex-modification pipeline, so the hyper rule's `ctrl+opt+cmd` is never
   seen by the swap rule.

## The binds work without Karabiner

Nothing in `aerospace.toml` depends on this file. The binds are plain
`ctrl-alt-cmd-*`, so physically holding Control+Option+Command reaches all of
them whether Karabiner is running or not. Left Option is a convenience alias
for that chord, not a prerequisite -- so a machine without Karabiner, or one
where the driver extension hasn't been approved yet, still has a working WM
(and stock macOS Cmd shortcuts, since the swap is off too).

## Setup that can't be scripted

home-manager links this config and nix-darwin installs the cask, but
Karabiner ships a DriverKit system extension, so it needs an admin password
and two approvals in System Settings that no script can grant.

Approve the driver extension (System Settings > General > Login Items &
Extensions > Driver Extensions) and grant Input Monitoring to
`Karabiner-Elements` and `karabiner_grabber` when prompted.

Worth checking once it is running, in this order -- each isolates one rule:

| press | in | expect |
| --- | --- | --- |
| `L-Opt+2` | anywhere | AeroSpace switches to workspace 2 |
| `L-Opt+shift+2` | anywhere | focused window moves to workspace 2 |
| `R-Opt+3` | any text field | types `#` (right Option untouched) |
| `Ctrl+C` | Orion | copies |
| `Ctrl+C` | Ghostty | interrupts, does **not** copy |
| `Cmd+Space` | Ghostty | opens Raycast, **not** Spotlight |
| `Ctrl+Tab` | Orion, 2+ tabs | next tab, **no** app switcher |
| Caps Lock (tap) | nvim insert mode | leaves insert mode |
| `Caps+C` | Orion | copies |
| `Caps+C` | Ghostty | interrupts |
| `Caps+Space` | Orion | opens Raycast, **not** Spotlight |
| `Ctrl+Delete` | Orion, mid-word | deletes the whole word |

**Karabiner-EventViewer** (installed alongside) shows exactly what each press
resolves to, which is the fastest way to debug a rule that does not fire.

## Drift

Karabiner's Settings GUI rewrites `karabiner.json` on save, normalising and
padding it with every default key. Edit the file here rather than using the
GUI; if the GUI does rewrite it, `git diff` will show the churn. Not bad
enough to give up managing the file -- Karabiner reloads live on file change,
so editing it directly works fine.
