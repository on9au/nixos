#!/bin/bash

# Long-running: Waybar reads a line each time we print one. We poll fcitx5 but
# only emit on an actual change, so Waybar re-renders on switches rather than
# on every tick. (classicui doesn't emit the kimpanel D-Bus signals, so polling
# is the only option here.)

prev=""

while :; do
	# Get the active fcitx5 input method name
	layout=$(fcitx5-remote -n 2>/dev/null)

	# Format the output for Waybar (Shorten long names if necessary)
	case "$layout" in
	"keyboard-us") current="US" ;;
	"pinyin") current="CN" ;;
	"mozc") current="JP" ;;
	*) current="$layout" ;;
	esac

	if [ "$current" != "$prev" ]; then
		printf '%s\n' "$current"
		prev="$current"
	fi

	sleep 0.5
done
