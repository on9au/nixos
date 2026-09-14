#!/bin/sh
# Run from aerospace.toml's after-startup-command, so this fires once per
# AeroSpace start (every login, since start-at-login is on) -- the macOS
# analog of ../hypr/autostart.lua + hosts/desktop/autostart.lua.
#
# Mirrors the desktop host's assignments exactly (kitty -> Ghostty, same
# workspace numbers): terminal on 1, browser on 2, Discord on 6, Spotify on
# 7. Steam isn't ported -- it was tray-only there (-silent, no window to
# place) and SketchyBar has no systray to put an icon in anyway.

set -eu

# Windows already open when AeroSpace starts get adopted into whatever
# workspace they're on -- and that adoption can land them in accordion
# instead of default-root-container-layout's 'tiles', since AeroSpace has
# no tiled arrangement to infer from windows that already existed. Force
# every workspace back to tiles as a backstop before placing anything else.
sleep 1
for w in $(aerospace list-workspaces --all); do
  aerospace layout --workspace "$w" --root tiles >/dev/null 2>&1 || true
done

# Launch an app and move its window to a workspace, without switching focus
# there (move-node-to-workspace's default -- --focus-follows-window would
# opt into jumping). The placement is scoped to this one launch, not a
# standing window-id/app-id match, so it doesn't run again and doesn't
# affect a second window opened later by hand -- same reasoning as
# launch.lua's app_on doc comment: a persistent match-on-class rule "would
# drag every future window of that app to the workspace".
place_on() {
  bundle_id="$1"
  app_name="$2"
  workspace="$3"

  open -b "$bundle_id" 2>/dev/null || open -a "$app_name"

  # Electron apps (Discord, Spotify) take a few seconds to create their
  # window on a cold start; poll rather than guessing a fixed sleep.
  # --app-bundle-id is a filter, not a selector on its own -- it has to be
  # paired with --monitor/--workspace/--all as the base selector, or
  # AeroSpace rejects it outright ("Mandatory option is not specified").
  #
  # 30s, not 10: measured the browser taking longer than a 10s poll window on a
  # cold launch (no process running yet at all) -- it missed the window and
  # landed wherever was focused instead of its target workspace.
  win_id=""
  i=0
  while [ "$i" -lt 300 ]; do
    win_id=$(aerospace list-windows --monitor all --app-bundle-id "$bundle_id" --format "%{window-id}" 2>/dev/null | head -1)
    [ -n "$win_id" ] && break
    sleep 0.1
    i=$((i + 1))
  done

  [ -n "$win_id" ] && aerospace move-node-to-workspace --window-id "$win_id" "$workspace" >/dev/null 2>&1 || true
}

place_on com.mitchellh.ghostty Ghostty 1
place_on com.kagi.kagimacOS Orion 2
place_on com.hnc.Discord Discord 6
place_on com.spotify.client Spotify 7
