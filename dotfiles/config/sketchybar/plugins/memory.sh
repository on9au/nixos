#!/bin/sh
# waybar showed used/total from /proc/meminfo. macOS's raw vm_stat "free
# pages" figure is not a good analog -- it excludes reclaimable inactive
# pages and reads as ~98% used on an idle machine. memory_pressure's
# "System-wide memory free percentage" already accounts for that the same
# way Activity Monitor's memory pressure gauge does.
free_pct=$(memory_pressure | awk -F': ' '/System-wide memory free percentage/ {gsub(/%/, "", $2); print $2}')
used_pct=$((100 - free_pct))

sketchybar --set "$NAME" label="${used_pct}%"
