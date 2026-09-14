#!/bin/bash
# custom/kdeconnect -- the paired phone: whether it is reachable, and its
# battery. Prints one JSON object per run; waybar re-runs it on the interval in
# config.jsonc and on RTMIN+9, which the actions below raise so a ring or a
# clipboard send is reflected immediately instead of waiting out the interval.
#
# Talks to kdeconnectd over D-Bus rather than through kdeconnect-cli, which can
# list and pair devices but has no way to read a battery. gdbus rather than
# qdbus for that: gdbus comes from glib2, which waybar already links against,
# where qdbus would mean installing qt5-tools for one property read.
#
# kdeconnectd itself is not started here. It ships an XDG autostart entry that
# uwsm honours (see hypr/autostart.lua), and it is D-Bus activatable on top of
# that -- so the daemon is already up by the time the bar first polls.

set -u

bus=org.kde.kdeconnect
root=/modules/kdeconnect

# Battery percentages at which the module goes yellow, then red. Same numbers
# as the laptop battery module in config.jsonc, so the two read alike.
warning=30
critical=15

call() { # object-path  interface.method  [args...]
	gdbus call -e -d "$bus" -o "$1" -m "${@:2}" 2>/dev/null
}

# gdbus prints a property as (<value>,), a string as (<'value'>,).
prop() { # object-path  interface  property
	call "$1" org.freedesktop.DBus.Properties.Get "$2" "$3" |
		sed -e 's/^(<//' -e 's/>,)$//' -e "s/^'//" -e "s/'$//"
}

# Paired device ids, one per line. The argument is onlyReachable.
devices() {
	call "$root" "$bus.daemon.devices" "$1" true |
		grep -oE "'[^']+'" | tr -d "'"
}

# The device the click actions talk to: the first reachable one.
target() {
	devices true | head -n1
}

refresh() {
	pkill -RTMIN+9 waybar || true
}

json_escape() {
	sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

status() {
	# Asking the bus who owns the name rather than calling into kdeconnectd:
	# a plain gdbus call is service-activating and would start the daemon from
	# the status bar on a machine where it is deliberately not running.
	local owner
	owner=$(gdbus call -e -d org.freedesktop.DBus -o /org/freedesktop/DBus \
		-m org.freedesktop.DBus.NameHasOwner "$bus" 2>/dev/null)
	[[ $owner == *true* ]] || exit 0

	local paired
	paired=$(devices false)
	# Nothing paired -- no output, which hides the module. Same trick as
	# custom/nolock: the phone icon exists only when there is a phone.
	[ -n "$paired" ] || exit 0

	local id dev name charge charging
	local text="" alt="disconnected" classes='"disconnected"' tooltip="" found=""

	for id in $paired; do
		dev=$root/devices/$id
		name=$(prop "$dev" "$bus.device" name | json_escape)

		if [ "$(prop "$dev" "$bus.device" isReachable)" != "true" ]; then
			tooltip+="$name -- offline\\n"
			continue
		fi

		charge=""
		if [ "$(prop "$dev/battery" "$bus.device.battery" hasBattery)" = "true" ]; then
			charge=$(prop "$dev/battery" "$bus.device.battery" charge)
			charging=$(prop "$dev/battery" "$bus.device.battery" isCharging)
		fi

		if [ -n "$charge" ]; then
			tooltip+="$name -- ${charge}%"
			[ "$charging" = "true" ] && tooltip+=" (charging)"
			tooltip+="\\n"
		else
			tooltip+="$name -- connected\\n"
		fi

		# The bar shows the first reachable device; the rest are in the
		# tooltip. Two phones on one desktop is the rare case, and a bar that
		# grows a module per device is worse than a tooltip.
		[ -n "$found" ] && continue
		found=y
		alt="connected"
		classes='"connected"'
		text="$charge${charge:+%}"

		if [ "${charging:-}" = "true" ]; then
			classes+=',"charging"'
		elif [ -n "$charge" ] && [ "$charge" -le "$critical" ]; then
			classes+=',"critical"'
		elif [ -n "$charge" ] && [ "$charge" -le "$warning" ]; then
			classes+=',"warning"'
		fi
	done

	tooltip+="left: open KDE Connect\\nmiddle: send clipboard\\nright: ring the phone"

	printf '{"text":"%s","alt":"%s","class":[%s],"tooltip":"%s"}\n' \
		"$text" "$alt" "$classes" "$tooltip"
}

case "${1:-status}" in
status)
	status
	;;
ring)
	id=$(target) && [ -n "$id" ] &&
		call "$root/devices/$id/findmyphone" "$bus.device.findmyphone.ring" >/dev/null
	refresh
	;;
clipboard)
	# Push what is on the clipboard now. KDE Connect can sync automatically,
	# but that is off by default on the phone side and this is the explicit
	# version of it.
	id=$(target) && [ -n "$id" ] && kdeconnect-cli --send-clipboard -d "$id"
	refresh
	;;
*)
	echo "usage: kdeconnect.sh [status|ring|clipboard]" >&2
	exit 2
	;;
esac
