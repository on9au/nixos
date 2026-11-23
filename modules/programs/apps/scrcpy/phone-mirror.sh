# phone-mirror -- open the paired Android phone in scrcpy, over wireless
# debugging (or USB if it's plugged in).
#
# Pair once with `adb pair <ip>:<port> <code>` from the phone's Wireless
# debugging screen. After that it is found over mDNS (avahi) by itself, but
# wireless debugging switches off on a reboot or a Wi-Fi change, hence the
# notification when nothing turns up.

# Already open: bring it forward rather than starting a second mirror.
if pgrep -x scrcpy >/dev/null; then
    hyprctl dispatch 'hl.dsp.focus({ window = "class:^\\.scrcpy-wrapped$" })' >/dev/null
    exit 0
fi

device() {
    adb devices | awk 'NR > 1 && $2 == "device" && !found { print $1; found = 1 }'
}

adb start-server >/dev/null 2>&1

# nixpkgs builds adb without mDNS, so avahi finds the phone's wireless
# debugging port, which changes every time it is switched on.
serial=$(device)
if [ -z "$serial" ]; then
    avahi-browse -rpt _adb-tls-connect._tcp |
        awk -F';' '$1 == "=" && $3 == "IPv4" { print $8 ":" $9 }' |
        while read -r addr; do timeout 10 adb connect "$addr" >/dev/null 2>&1; done || true
    serial=$(device)
fi

if [ -z "$serial" ]; then
    notify-send -a 'Phone Mirroring' -i scrcpy 'Phone not found' \
        'Turn on Wireless debugging in Developer options, on the same network.'
    exit 1
fi

log=$(mktemp)
trap 'rm -f "$log"' EXIT

if ! scrcpy -s "$serial" --window-title=Phone \
    --turn-screen-off --power-off-on-close 2>"$log"; then
    notify-send -a 'Phone Mirroring' -i scrcpy -u critical 'scrcpy failed' \
        "$(grep -m1 ERROR "$log" || tail -n1 "$log")"
    exit 1
fi
