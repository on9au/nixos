#!/bin/sh
# Scaffold the mautrix bridges against tuwunel. Re-runnable: existing configs
# and registrations are patched in place, never regenerated, so the tokens
# tuwunel already knows stay valid.
#
# The containers are declared in default.nix; keep the images below in step
# with it. Run as root -- the bridge data lives under /var/lib/homelab -- and
# restart tuwunel afterwards to load new registrations.
#
# Two config schemas are in play. The date-versioned bridges (telegram,
# whatsapp, gmessages, meta) are bridgev2: top-level `database` and
# `double_puppet.secrets`. mautrix-discord 0.7.6 predates that and keeps the
# database under `appservice.database` with double puppeting in
# `bridge.login_shared_secret_map`. Hence the per-bridge schema flag.
#
# Double puppeting uses one shared `doublepuppet` appservice whose token claims
# the whole local user namespace non-exclusively; every bridge reuses it, so
# there is nothing per-bridge to authorise.

set -eu

DOMAIN=opena0.net
HS_ADDRESS=http://tuwunel:6167
ADMIN='@djpro:opena0.net'
DATA_DIR=/var/lib/homelab/bridges
REG_DIR=/var/lib/homelab/tuwunel/appservices
DP_FILE="$REG_DIR/doublepuppet.yaml"

token() {
  od -An -tx1 -N32 /dev/urandom | tr -d ' \n'
}

mkdir -p "$REG_DIR"

# --- shared double-puppet appservice ------------------------------------
if [ ! -f "$DP_FILE" ]; then
  cat > "$DP_FILE" <<DP
# Grants the bridges permission to act as local users (double puppeting), so
# your own messages appear as you rather than as a bot. exclusive: false is
# essential -- an exclusive claim on this namespace would lock out real users
# and every other appservice.
id: doublepuppet
url: null
as_token: "$(token)"
hs_token: "$(token)"
sender_localpart: doublepuppet
rate_limited: false
namespaces:
  users:
    - regex: '@.*:$(echo "$DOMAIN" | sed 's/\./\\./g')'
      exclusive: false
DP
  echo "created $DP_FILE"
fi
DP_TOKEN=$(awk '/^as_token:/{gsub(/"/,"");print $2}' "$DP_FILE")

yq() {  # yq <datadir> <expr>
  docker run --rm --user root -v "$1":/w -w /w mikefarah/yq:latest -i "$2" config.yaml
}

# bridge <dir> <image> <port> <id> <bot> <schema> [extra-yq]
bridge() {
  dir=$1; image=$2; port=$3; id=$4; bot=$5; schema=$6; extra=${7:-}
  data="$DATA_DIR/$dir/data"
  mkdir -p "$data"

  # First run writes an example config and exits.
  if [ ! -f "$data/config.yaml" ]; then
    docker run --rm -v "$data":/data "$image" </dev/null >/dev/null 2>&1 || true
  fi

  # stdout only. The default config also logs to ./logs/bridge.log, which
  # duplicates what docker's journald log driver already collects -- and on the
  # old macOS host its chown EPERMed on virtiofs and crash-looped the bridge.
  common=".logging.writers = [{\"type\": \"stdout\", \"format\": \"pretty-colored\"}]
    | .homeserver.address = \"$HS_ADDRESS\"
    | .homeserver.domain = \"$DOMAIN\"
    | .appservice.address = \"http://mautrix-$dir:$port\"
    | .appservice.hostname = \"0.0.0.0\"
    | .appservice.port = $port
    | .appservice.id = \"$id\"
    | .appservice.bot.username = \"$bot\"
    | .bridge.permissions = {\"*\": \"relay\", \"$DOMAIN\": \"user\", \"$ADMIN\": \"admin\"}"

  # End-to-bridge encryption. Matrix clients create encrypted DMs by default, so
  # without this the bot cannot read its own management room -- it replies
  # "this bridge has not been configured to support encryption" and nothing
  # works. require stays false so an unencrypted room still functions.
  crypto='.allow = true | .default = true | .require = false | .allow_key_sharing = true'

  if [ "$schema" = "v2" ]; then
    yq "$data" "with(.encryption; $crypto)"
    yq "$data" "with(.direct_media;
        .enabled = true | .server_name = \"$dir-media.$DOMAIN\")"
    yq "$data" "$common
      | .database.type = \"sqlite3-fk-wal\"
      | .database.uri = \"file:/data/$dir.db?_txlock=immediate\"
      | .double_puppet.secrets = {\"$DOMAIN\": \"as_token:$DP_TOKEN\"}"
  else
    yq "$data" "with(.bridge.encryption; $crypto)"
    yq "$data" "with(.bridge.direct_media;
        .enabled = true | .server_name = \"$dir-media.$DOMAIN\")"
    yq "$data" "$common
      | .appservice.database.type = \"sqlite3-fk-wal\"
      | .appservice.database.uri = \"file:/data/$dir.db?_txlock=immediate\"
      | .bridge.login_shared_secret_map = {\"$DOMAIN\": \"as_token:$DP_TOKEN\"}"
  fi

  [ -z "$extra" ] || yq "$data" "$extra"

  # Second run generates registration.yaml and exits.
  if [ ! -f "$data/registration.yaml" ]; then
    docker run --rm -v "$data":/data "$image" </dev/null >/dev/null 2>&1 || true
  fi

  if [ -f "$data/registration.yaml" ]; then
    cp "$data/registration.yaml" "$REG_DIR/$id.yaml"
    printf '%-11s %-34s port=%-6s reg=ok\n' "$dir" "$image" "$port"
  else
    printf '%-11s %-34s port=%-6s reg=MISSING\n' "$dir" "$image" "$port"
  fi
}

M=dock.mau.dev/mautrix

bridge telegram  "$M/telegram:v26.07"  29317 telegram  telegrambot  v2
bridge whatsapp  "$M/whatsapp:v26.07"  29318 whatsapp  whatsappbot  v2
bridge discord   "$M/discord:v0.7.6"   29334 discord   discordbot   legacy
# Google Messages is the one bridge that cannot do direct media: RCS media has
# no HTTP URL the bridge could hand out, and the connector refuses to start
# ("the network connector does not support it") rather than ignoring it.
bridge gmessages "$M/gmessages:v26.05" 29336 gmessages gmessagesbot v2 \
  '.direct_media.enabled = false
   | .network.aggressive_reconnect = true'

# The meta family: Messenger and Instagram were split into separate bridges in
# July 2026 (ig- prefixed tags). They must not share a user namespace, hence
# the explicit username_template on each. Note username_template lives under
# `appservice`, not `bridge`.
bridge messenger "$M/meta:v26.07"      29321 messenger messengerbot v2 \
  '.network.mode = "messenger" | .appservice.username_template = "messenger_{{.}}"'
bridge instagram "$M/meta:ig-v26.07"   29322 instagram instagrambot v2 \
  '.appservice.username_template = "instagram_{{.}}"'

echo
echo "registrations in $REG_DIR:"
ls -1 "$REG_DIR"
