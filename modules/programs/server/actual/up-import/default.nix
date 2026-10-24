{
  config,
  lib,
  pkgs,
  ...
}: let
  session = import ../session.nix {
    config = config;
    pkgs = pkgs;
  };

  # @actual-app/api has to match the server's version: bump both together.
  # better-sqlite3 ships a prebuilt linux-x64 binary, so nothing compiles.
  up-import = pkgs.buildNpmPackage {
    pname = "up-import";
    version = "1.0.0";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [./package-lock.json ./package.json ./up-import.mjs];
    };
    npmDepsHash = "sha256-78CMu8Ti+ALY7HmDut1aFLThEMkPLVtAhT1DqkNJXiI=";
    nodejs = pkgs.nodejs_22;
    dontNpmBuild = true;
    meta.mainProgram = "up-import";
  };

  # Up name -> Actual name, for an account that isn't called the same in both.
  accountNames = {};

  runs = {
    # Every six hours, the last fortnight: Up can take days to settle.
    actual-up-import = {UP_SINCE_DAYS = "14";};
    # By hand: the whole history, once, after the dry run looks right.
    actual-up-import-all = {};
    actual-up-import-dry-run = {DRY_RUN = "1";};
  };

  # The full import leaves it, and the scheduled one waits for it, so nothing
  # reaches the budget before the dry run has been read.
  imported = "/var/lib/homelab/actual-up-import/.imported";
in {
  # Read-only at Up: it can't move money. Revoke or regenerate in the Up app,
  # Data sharing → Personal Access Token.
  sops.secrets."actual-up-import/up_token" = {};

  systemd.services =
    lib.mapAttrs (name: extraEnv: {
      description = "Import Up Bank transactions into Actual";
      after = ["docker-actual.service" "network-online.target"];
      wants = ["network-online.target"];
      environment =
        {
          ACTUAL_SERVER_URL = "https://budget.opena0.net";
          UP_ACCOUNT_NAMES = builtins.toJSON accountNames;
          TZ = config.time.timeZone;
        }
        // extraEnv;
      unitConfig.ConditionPathExists =
        ["/var/lib/homelab/.restored"]
        ++ lib.optional (name == "actual-up-import") imported;
      serviceConfig = {
        Type = "oneshot";
        # "+" runs as root: the session is made in Actual's database.
        ExecStartPre = "+${lib.getExe session} mint /run/${name}/session.env${lib.optionalString (name != "actual-up-import") " --ask"}";
        ExecStart = lib.getExe up-import;
        ExecStartPost = lib.mkIf (name == "actual-up-import-all") "+${pkgs.coreutils}/bin/install -D /dev/null ${imported}";
        ExecStopPost = "+${lib.getExe session} revoke /run/${name}/session.env";
        EnvironmentFile = "-/run/${name}/session.env";
        LoadCredential = "up-token:${config.sops.secrets."actual-up-import/up_token".path}";
        RuntimeDirectory = name;
        RuntimeDirectoryMode = "0700";
        TimeoutStartSec = "1h";

        DynamicUser = true;
        PrivateTmp = true;
        WorkingDirectory = "/tmp";
        CapabilityBoundingSet = "";
        LockPersonality = true;
        PrivateDevices = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = ["@system-service" "~@privileged"];
        UMask = "0077";
      };
    })
    runs;

  systemd.timers.actual-up-import = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "00/6:00";
      Persistent = true;
      RandomizedDelaySec = "10m";
    };
  };
}
