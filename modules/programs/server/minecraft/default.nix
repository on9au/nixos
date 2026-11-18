# Fabric servers, each behind lazymc. lazymc holds the server's port, starts
# the server when someone joins and stops it once it has sat empty, so an idle
# server holds no memory.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  dataDir = config.services.minecraft-servers.dataDir;
  players = import ./players.nix;
  servers = import ./servers.nix;

  # Where lazymc reaches the server itself, on loopback.
  internalPort = server: server.port + 10000;

  # The game version comes from the server's packwiz pack.
  pack = name: builtins.fromTOML (builtins.readFile ./servers/${name}/pack.toml);

  # TEMP(nix-minecraft#211): its Fabric servers launch nixpkgs' default
  # jre_headless rather than the Java the game needs; 26.x won't start on 21.
  serverPackage = name:
    assert lib.assertMsg (lib.versionOlder pkgs.jre_headless.version "25")
    "TEMP: nixpkgs' jre_headless is ${pkgs.jre_headless.version}; drop the jre_headless override in programs/server/minecraft/default.nix";
      pkgs.fabricServers."fabric-${lib.replaceStrings ["."] ["_"] (pack name).versions.minecraft}".override {
        jre_headless = pkgs.jdk25_headless;
      };

  # The pack's mods, from the url and hash packwiz recorded, less client-only ones.
  mods = name: let
    dir = ./servers/${name}/mods;
  in
    lib.pipe (builtins.readDir dir) [
      (lib.filterAttrs (file: _: lib.hasSuffix ".pw.toml" file))
      (lib.mapAttrsToList (file: _: builtins.fromTOML (builtins.readFile (dir + "/${file}"))))
      (lib.filter (mod: (mod.side or "both") != "client"))
      (map (mod:
        assert lib.assertMsg (mod.download ? url)
        "${name}: ${mod.name} has no download url; packwiz leaves it out for CurseForge-only mods, so use the Modrinth one";
          pkgs.fetchurl {
            name = mod.filename;
            url = mod.download.url;
            ${mod.download.hash-format} = mod.download.hash;
          }))
    ];

  lazymcConfig = name: server:
    (pkgs.formats.toml {}).generate "lazymc-${name}.toml" {
      config.version = pkgs.lazymc.version;
      public.address = "0.0.0.0:${toString server.port}";
      server = {
        address = "127.0.0.1:${toString (internalPort server)}";
        command = "${lib.getExe (serverPackage name)} -Xms1G -Xmx${toString server.memory}G";
        # Absolute: lazymc resolves a relative one against its config file,
        # which is in the store.
        directory = "${dataDir}/${name}";
        # A frozen JVM keeps its memory; a stopped one gives it back.
        freeze_process = false;
        # Starts the server once at boot so lazymc learns its version. Until
        # then a sleeping server lists as lazymc's built-in 1.20.3, which
        # clients show as incompatible. Not probe_on_start: its probe logs in
        # as a fake player, which an online-mode server refuses.
        wake_on_start = true;
      };
      time.sleep_after = 600;
      # nix-minecraft writes server.properties on every start.
      advanced.rewrite_server_properties = false;
    };
in {
  nixpkgs.overlays = [inputs.nix-minecraft.overlay];

  # Edits the packs in servers/; see README.md.
  environment.systemPackages = [pkgs.packwiz];

  services.minecraft-servers = {
    enable = true;
    eula = true;
    # The journal for logs, and `echo <command> > /run/minecraft/<name>.stdin`
    # for the console: lazymc passes its stdin on to the server.
    managementSystem = {
      systemd-socket.enable = true;
      tmux.enable = false;
    };

    servers =
      lib.mapAttrs (name: server: {
        enable = true;
        # nix-minecraft starts `package`; here that is lazymc, which starts the
        # real server. Its heap is set in lazymcConfig, so no jvmOpts.
        package = pkgs.writeShellScriptBin "lazymc-${name}" ''
          exec ${lib.getExe pkgs.lazymc} --config ${lazymcConfig name server} start
        '';
        jvmOpts = "";
        # nix-minecraft's stop hook sends `stop`, which only a running server
        # hears, then waits on lazymc, which never exits by itself. systemd's
        # SIGTERM reaches both, and the server saves on it.
        stopCommand = null;
        # lazymc wakes the server only for a player on it.
        whitelist = lib.optionalAttrs server.whitelist players;
        serverProperties =
          {
            enforce-whitelist = server.whitelist;
            online-mode = true;
            server-ip = "127.0.0.1";
            server-port = internalPort server;
            white-list = server.whitelist;
          }
          // server.properties;
        symlinks =
          # Each jar on its own, so mods/ stays writable: LuckPerms keeps its
          # data in mods/luckperms.
          lib.listToAttrs (map (mod: lib.nameValuePair "mods/${mod.name}" mod) (mods name))
          # servers/<name>/datapack, loaded into the world. The world picks up a
          # new pack by itself.
          // lib.optionalAttrs (builtins.pathExists ./servers/${name}/datapack) {
            "world/datapacks/${name}" = ./servers/${name}/datapack;
          };
      })
      servers;
  };

  # The worlds go in the daily backup (programs/services/backup.nix); /srv is
  # its own subvolume. An awake server writes out every chunk it holds first,
  # so the snapshot catches a whole save rather than one half-written.
  # A sleeping one has nothing unsaved, and lazymc's stdin would hold the
  # command for its next start.
  backupSubvolumes = ["/srv"];
  backupPrepare = lib.concatStrings (lib.mapAttrsToList (name: server: ''
      if ss -ltnH "sport = :${toString (internalPort server)}" | grep -q .; then
        echo 'save-all flush' > ${config.services.minecraft-servers.managementSystem.systemd-socket.stdinSocket.path name}
        sleep 15
      fi
    '')
    servers);
  # The server downloads these again by itself.
  services.restic.backups.r2.exclude = [
    "minecraft/*/.fabric"
    "minecraft/*/libraries"
    "minecraft/*/versions"
  ];

  systemd.slices.minecraft.sliceConfig = {
    # Below the default 100, so a game being played on the desktop wins.
    CPUWeight = 50;
    MemoryMax = "12G";
  };

  systemd.services =
    lib.mapAttrs' (name: server:
      lib.nameValuePair "minecraft-server-${name}" {
        serviceConfig = {
          # The heap plus the JVM's own overhead.
          MemoryMax = "${toString (server.memory * 1024 + 1536)}M";
          Slice = "minecraft.slice";
        };
      })
    servers
    // {
      # `ss` for backupPrepare above.
      restic-backups-r2.path = [pkgs.iproute2];
    };

  # Players come in through the proxy VPS over Tailscale, or straight in on the
  # desktop's LAN port, enp8s0, rather than out to the VPS and back.
  networking.firewall.interfaces = lib.genAttrs ["enp8s0" "tailscale0"] (_: {
    allowedTCPPorts = lib.mapAttrsToList (_: server: server.port) servers;
  });
}
