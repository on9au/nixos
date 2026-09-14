#!/bin/sh
# $NAME is "space.<n>"; $FOCUSED_WORKSPACE comes from aerospace.toml's
# exec-on-workspace-change trigger.
sid="${NAME#space.}"

if [ "$sid" = "$FOCUSED_WORKSPACE" ]; then
  # Mauve pill, dark text -- same focused-window colour as
  # ../../hypr/looknfeel.lua's active_border.
  sketchybar --set "$NAME" background.drawing=on background.color=0xffcba6f7 icon.color=0xff1e1e2e
else
  sketchybar --set "$NAME" background.drawing=off icon.color=0xffcdd6f4
fi
