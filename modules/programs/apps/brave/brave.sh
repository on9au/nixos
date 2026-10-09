# brave -- start Brave, unlocking its profile first.
#
# The profile is a gocryptfs vault opened with a PIN. gocryptfs unmounts it
# once Brave has quit and nothing has used it for a couple of minutes, so a
# closed Brave is a locked one. The cache is kept inside the vault too; Brave
# would otherwise write it to ~/.cache in the clear.

vault=$HOME/.local/share/brave-vault
profile=$HOME/.config/BraveSoftware

if ! mountpoint -q "$profile"; then
    # Clears a mount left dead when gocryptfs was killed, e.g. at logout.
    fusermount3 -uz "$profile" 2>/dev/null || true

    pin=$(fuzzel --dmenu --password --prompt-only "PIN: " </dev/null) || exit 1
    if ! printf '%s' "$pin" | gocryptfs -q -idle 2m "$vault" "$profile"; then
        notify-send "Incorrect PIN"
        exit 1
    fi
fi

exec "$BRAVE" --disk-cache-dir="$profile/cache" "$@"
