# brave -- start Brave, unlocking its profile first.
#
# The profile is a gocryptfs vault opened with a PIN and locked again as soon
# as Brave exits. The cache is kept inside the vault too; Brave would
# otherwise write it to ~/.cache in the clear.

vault=$HOME/.local/share/brave-vault
profile=$HOME/.config/BraveSoftware

if ! mountpoint -q "$profile"; then
    # Clears a mount left dead when gocryptfs was killed, e.g. at logout.
    fusermount3 -uz "$profile" 2>/dev/null || true

    pin=$(fuzzel --dmenu --password --prompt-only "PIN: " </dev/null) || exit 1
    # -idle is the fallback for when this script is killed before Brave exits.
    if ! printf '%s' "$pin" | gocryptfs -q -idle 2m "$vault" "$profile"; then
        notify-send "Incorrect PIN"
        exit 1
    fi
fi

status=0
"$BRAVE" --disk-cache-dir="$profile/cache" "$@" || status=$?

# A brave run while one is already open hands over to it and returns at once;
# the vault is busy then, so the unmount fails and it stays open. Brave's
# helper processes can outlive the browser by a few seconds, hence the retries.
for _ in $(seq 20); do
    fusermount3 -u "$profile" 2>/dev/null && break
    sleep 0.5
done
exit "$status"
