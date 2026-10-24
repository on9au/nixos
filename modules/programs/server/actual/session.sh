# Logs a job on this box in to Actual as the budget's owner. Kanidm is the
# only login, and a job can't do one, so this makes a session straight in
# Actual's database instead. It lasts three hours; revoke deletes it.
#
#   actual-session mint <env file> [--ask]
#     writes ACTUAL_SESSION_TOKEN and ACTUAL_BUDGET_ID, and for an encrypted
#     budget ACTUAL_E2E_PASSWORD, asked for on the terminal with --ask
#   actual-session revoke <env file>

# Inside the server's container, as its user, with its own better-sqlite3: the
# volume is reached the way the server reaches it, and anything sqlite writes
# beside the database stays the server's. One row per line, columns joined by |.
sql() {
  docker exec -u 1001:1001 actual node -e '
    const db = new (require("better-sqlite3"))("/data/server-files/account.sqlite", {fileMustExist: true, timeout: 5000});
    const [query, ...params] = process.argv.slice(1);
    const statement = db.prepare(query);
    if (statement.reader) for (const row of statement.raw().all(...params)) console.log(row.join("|"));
    else statement.run(...params);
  ' -- "$@"
}

case "$1" in
mint)
  owner=$(sql "SELECT id FROM users WHERE owner = 1 AND enabled = 1")
  if [ -z "$owner" ]; then
    echo "Actual has no owner yet: log in at https://budget.opena0.net first" >&2
    exit 1
  fi
  budget=$(sql "SELECT group_id FROM files WHERE owner = ? AND NOT deleted" "$owner")
  if [ "$(printf '%s\n' "$budget" | grep -c .)" != 1 ]; then
    echo "Expected one budget, found: $(sql "SELECT name FROM files WHERE owner = ? AND NOT deleted" "$owner" | paste -sd ,)" >&2
    exit 1
  fi

  token=$(cat /proc/sys/kernel/random/uuid)
  sql "INSERT INTO sessions (token, expires_at, user_id, auth_method) VALUES (?, ?, ?, 'openid')" "$token" "$(($(date +%s) + 10800))" "$owner"
  umask 077
  printf 'ACTUAL_SESSION_TOKEN=%s\nACTUAL_BUDGET_ID=%s\n' "$token" "$budget" >"$2"

  if [ -n "$(sql "SELECT encrypt_keyid FROM files WHERE group_id = ?" "$budget")" ]; then
    if [ "${3:-}" != --ask ]; then
      echo "The budget is encrypted, and nobody is at a terminal to give its password" >&2
      exit 1
    fi
    printf 'ACTUAL_E2E_PASSWORD=%s\n' "$(systemd-ask-password "Actual budget encryption password:")" >>"$2"
  fi
  ;;
revoke)
  [ -f "$2" ] || exit 0
  token=$(sed -n 's/^ACTUAL_SESSION_TOKEN=//p' "$2")
  sql "DELETE FROM sessions WHERE token = ?" "$token"
  rm -f "$2"
  ;;
*)
  echo "usage: actual-session mint|revoke <env file> [--ask]" >&2
  exit 2
  ;;
esac
