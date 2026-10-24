{
  config,
  lib,
  pkgs,
  ...
}: let
  # Started by hand, never on boot. Upstream's README calls dry run the
  # default, but an unlisted feature is off, so it has to be listed.
  runs = {
    actual-ai = ["classifyOnStartup"];
    actual-ai-dry-run = ["classifyOnStartup" "dryRun"];
  };

  # The run logs in as the budget's owner with a session made here, in
  # Actual's own database, rather than through Kanidm. It lasts three hours and
  # is deleted when the unit stops. As uid 1001, so a journal file sqlite
  # leaves behind stays writable by the server.
  sqlite = ''setpriv --reuid=1001 --regid=1001 --clear-groups sqlite3 -cmd ".timeout 5000" "$(docker volume inspect -f '{{.Mountpoint}}' actual_data)/server-files/account.sqlite"'';

  mint = name: ''
    owner=$(${sqlite} "SELECT id FROM users WHERE owner = 1 AND enabled = 1")
    if [ -z "$owner" ]; then
      echo "Actual has no owner yet: log in at https://budget.opena0.net first" >&2
      exit 1
    fi
    budgets=$(${sqlite} "SELECT group_id FROM files WHERE owner = '$owner' AND NOT deleted")
    if [ "$(printf '%s\n' "$budgets" | grep -c .)" != 1 ]; then
      echo "Expected one budget, found: $(${sqlite} "SELECT name FROM files WHERE owner = '$owner' AND NOT deleted")" >&2
      exit 1
    fi

    token=$(cat /proc/sys/kernel/random/uuid)
    ${sqlite} "INSERT INTO sessions (token, expires_at, user_id, auth_method) VALUES ('$token', $(($(date +%s) + 10800)), '$owner', 'openid')"
    printf 'ACTUAL_SESSION_TOKEN=%s\nACTUAL_BUDGET_ID=%s\n' "$token" "$budgets" > /run/${name}/session.env

    # An encrypted budget's password is asked for on the terminal running
    # systemctl start, and only ever kept in /run.
    if [ -n "$(${sqlite} "SELECT encrypt_keyid FROM files WHERE group_id = '$budgets'")" ]; then
      printf 'ACTUAL_E2E_PASSWORD=%s\n' "$(systemd-ask-password "Actual budget encryption password:")" >> /run/${name}/session.env
    fi
  '';

  revoke = name: ''
    if [ -f /run/${name}/session.env ]; then
      token=$(sed -n 's/^ACTUAL_SESSION_TOKEN=//p' /run/${name}/session.env)
      ${sqlite} "DELETE FROM sessions WHERE token = '$token'"
    fi
  '';
in {
  # Shared with Open WebUI.
  sops.templates."actual-ai.env".content = ''
    OPENAI_API_KEY=${config.sops.placeholder."open-webui/deepseek_api_key"}
  '';

  virtualisation.oci-containers.containers =
    lib.mapAttrs (name: features: {
      image = "sakowicz/actual-ai:3.0.2";
      autoStart = false;
      # node directly rather than `npm run prod`, so the preload only loads in the app.
      cmd = ["node" "dist/app.js"];
      environment = {
        # Through Caddy rather than the proxy network: the token travels over
        # TLS, and nothing else on that network is reachable from here.
        ACTUAL_SERVER_URL = "https://budget.opena0.net";
        FEATURES = builtins.toJSON features;
        LLM_PROVIDER = "openai";
        NODE_OPTIONS = "--require /opt/session-token.cjs";
        OPENAI_BASE_URL = "https://api.deepseek.com/v1";
        OPENAI_MODEL = "deepseek-flash";
      };
      environmentFiles = [
        config.sops.templates."actual-ai.env".path
        "/run/${name}/session.env"
      ];
      volumes = ["${./session-token.cjs}:/opt/session-token.cjs:ro"];
      extraOptions = ["--read-only" "--tmpfs=/tmp"];
    })
    runs;

  systemd.services = lib.mapAttrs' (name: _:
    lib.nameValuePair "docker-${name}" {
      path = [pkgs.sqlite pkgs.util-linux];
      preStart = mint name;
      postStop = revoke name;
      serviceConfig = {
        # One classification, then the process exits.
        Restart = lib.mkForce "no";
        RuntimeDirectory = name;
        RuntimeDirectoryMode = "0700";
        RuntimeMaxSec = "2h";
      };
    })
  runs;
}
