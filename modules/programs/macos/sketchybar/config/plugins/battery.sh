#!/bin/sh
# waybar's battery module read /sys/class/power_supply; pmset is the macOS
# equivalent. No "device" disambiguation needed like the laptop's
# intel_backlight/nvidia_0 trap -- a MacBook only has the one battery.
percentage=$(pmset -g batt | grep -Eo '[0-9]+%' | tr -d '%')
charging=$(pmset -g batt | grep 'AC Power')

if [ -z "$percentage" ]; then
  exit 0
fi

case "$percentage" in
  9[0-9]|100) icon="󰁹" ;;
  [6-8][0-9]) icon="󰂁" ;;
  [3-5][0-9]) icon="󰁿" ;;
  [1-2][0-9]) icon="󰁼" ;;
  *) icon="󰁺" ;;
esac

if [ -n "$charging" ]; then
  icon="󰂄"
fi

sketchybar --set "$NAME" icon="$icon" label="${percentage}%"
