#!/bin/sh
# waybar's cpu module read /proc/stat; macOS has no equivalent, so this
# parses `top`'s one-shot summary line instead ("CPU usage: N% user, N% sys,
# N% idle"). user+sys is close enough to waybar's single "usage" figure.
usage=$(top -l 1 -n 0 | awk -F'[:,]' '/CPU usage/ {
  gsub(/[^0-9.]/, "", $2); gsub(/[^0-9.]/, "", $3); printf "%.0f", $2 + $3
}')

sketchybar --set "$NAME" label="${usage}%"
