#!/bin/sh
# hyprland/window equivalent: currently focused app's name.
if [ "$SENDER" = "front_app_switched" ]; then
  sketchybar --set "$NAME" label="$INFO"
fi
