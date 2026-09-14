#!/bin/sh
# waybar picked whichever interface was actually carrying traffic and showed
# bandwidth/signal; this is the coarser macOS version -- default-route
# interface, offline icon if there's no route at all.
#
# Not showing the SSID: macOS gates real Wi-Fi network names behind Location
# Services permission (SSID can be used to geolocate), and a headless
# LaunchAgent script has no window to trigger that permission prompt from --
# only a GUI app with a CLLocationManager call gets asked. Every CLI path
# (ipconfig getsummary, networksetup -getairportnetwork, system_profiler)
# comes back either empty or the literal string "<redacted>" instead of
# failing cleanly, so there's nothing here to reliably parse. Interface name
# is a fine enough stand-in for "which network am I on".
iface=$(route get default 2>/dev/null | awk '/interface:/ {print $2}')

if [ -z "$iface" ]; then
  sketchybar --set "$NAME" icon="󰖪" label="offline"
else
  sketchybar --set "$NAME" icon="󰖩" label="$iface"
fi
