#!/bin/sh
# pulseaudio module equivalent. volume_change is a built-in SketchyBar event
# on macOS -- no polling script needed, unlike cpu/memory/network above.
if [ "$SENDER" = "volume_change" ]; then
  volume="$INFO"

  case "$volume" in
    [6-9][0-9]|100) icon="󰕾" ;;
    [3-5][0-9]) icon="󰖀" ;;
    [1-9]|[1-2][0-9]) icon="󰕿" ;;
    *) icon="󰝟" ;;
  esac

  sketchybar --set "$NAME" icon="$icon" label="${volume}%"
fi
