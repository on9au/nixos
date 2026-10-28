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

  session = import ../session.nix {
    config = config;
    pkgs = pkgs;
  };
in {
  # Shared with Open WebUI.
  sops.templates."actual-ai.env".content = ''
    OPENAI_API_KEY=${config.sops.placeholder."open-webui/deepseek_api_key"}
  '';

  virtualisation.oci-containers.containers =
    lib.mapAttrs (name: features: {
      image = "sakowicz/actual-ai:3.0.3";
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
      # The run logs in with a session made for it, deleted when it stops.
      preStart = "${lib.getExe session} mint /run/${name}/session.env --ask";
      postStop = "${lib.getExe session} revoke /run/${name}/session.env";
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
