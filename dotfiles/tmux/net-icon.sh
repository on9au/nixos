#!/usr/bin/env bash
# pick icon based on the default route's interface
iface=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+' | head -1)
case "$iface" in
e* | en*) echo "󰈁" ;; # ethernet (eth0, enp...)
w* | wl*) echo "󰖩" ;; # wifi (wlan0, wlp...)
*) echo "󰛳" ;;        # fallback / unknown (vpn, tun, etc.)
esac
