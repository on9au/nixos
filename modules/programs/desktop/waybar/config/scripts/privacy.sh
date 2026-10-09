#!/usr/bin/env bash
# custom/privacy -- camera, mic and screen-capture indicators in one group,
# coloured like macOS's dots: green camera, orange mic, purple screen. Prints
# nothing while nothing is capturing, which hides the module.
#
# Not waybar's privacy module: that draws GTK theme icons, not Nerd Font
# glyphs, and only sees PipeWire. Most apps (Chromium, Zoom, OBS) open the
# webcam straight through V4L2, so the camera comes from /proc instead -- only
# this user's processes are visible there, which on a desktop is all of them.

set -u

# What was active on the last run, so an indicator that has just come on can
# get a flash-<label> class. style.css pulses the pill with it. The state file
# holds the active labels, the flash class and when it ends; a class kept
# across polls doesn't restart GTK's animation.
state=${XDG_RUNTIME_DIR:-/tmp}/waybar-privacy
{
	read -r previous
	read -r flash
	read -r flash_until
} <"$state" 2>/dev/null
previous=${previous:-}
flash=${flash:-}
flash_until=${flash_until:-0}
now=$(date +%s)

camera=$(
  find /proc/[0-9]*/fd -lname '/dev/video*' 2>/dev/null |
    cut -d/ -f3 | sort -u |
    while read -r pid; do basename "$(readlink "/proc/$pid/exe")" 2>/dev/null; done
)

# Running capture streams only; stream.monitor is a level meter such as
# pavucontrol's, not a recording.
output=$(pw-dump 2>/dev/null | jq -c --arg camera "$camera" --arg previous "$previous" '
	# NixOS wrappers rename the binary to .<name>-wrapped.
	def tidy: ltrimstr(".") | rtrimstr("-wrapped");
	def names(class):
		[.[] | .info.props? // {}
			| select(.["media.class"] == class and .["stream.monitor"] != true)
			| (.["application.name"] // .["node.name"] // .["media.name"] // "unknown")
			| tidy]
		| unique;
	def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");

	[.[] | select(.info.state? == "running")] as $running
	| [
		{icon: "󰖠", colour: "#a6e3a1", label: "Camera",
			apps: ($camera | split("\n") | map(select(. != "") | tidy) | unique)},
		{icon: "󰍬", colour: "#fab387", label: "Mic",
			apps: ($running | names("Stream/Input/Audio"))},
		{icon: "󱎴\u2009", colour: "#cba6f7", label: "Screen",
			apps: ($running | names("Stream/Input/Video"))}
	]
	| map(select(.apps != []))
	| ($previous | split(" ")) as $before
	| (map(.label | ascii_downcase) - $before) as $new
	| if . == [] then empty else {
		text: map("<span color=\"\(.colour)\">\(.icon)</span>") | join("\u2009\u2009"),
		tooltip: map("\(.label): \(.apps | join(", ") | esc)") | join("\n"),
		alt: map(.label | ascii_downcase) | join(" "),
		class: (if $new == [] then "" else "flash-\($new[0])" end)
	} end
')

if [ -z "$output" ]; then
	: >"$state"
	exit 0
fi

new=$(jq -r .class <<<"$output")
if [ -n "$new" ]; then
	# Two 2s polls, matching the animation in style.css.
	flash=$new
	flash_until=$((now + 3))
elif [ "$now" -ge "$flash_until" ]; then
	flash=
fi

printf '%s\n%s\n%s\n' "$(jq -r .alt <<<"$output")" "$flash" "$flash_until" >"$state"
jq -c --arg flash "$flash" '.class = $flash' <<<"$output"
