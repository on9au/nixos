{config, ...}: {
  sops.secrets."diun/discord_webhook" = {};

  sops.templates."diun.env" = {
    content = ''
      DIUN_NOTIF_DISCORD_WEBHOOKURL=${config.sops.placeholder."diun/discord_webhook"}
    '';
    restartUnits = ["docker-diun.service"];
  };

  virtualisation.oci-containers.containers.diun = {
    image = "crazymax/diun:4.33.0";
    cmd = ["serve"];
    environment = {
      DIUN_PROVIDERS_DOCKER = "true";
      DIUN_PROVIDERS_DOCKER_WATCHBYDEFAULT = "true";
      DIUN_WATCH_FIRSTCHECKNOTIF = "false";
      DIUN_WATCH_JITTER = "30s";
      # Daily at 08:00. Nothing here auto-updates -- Diun only says a newer image
      # exists, which matters most for the bridges: they talk to hostile APIs and
      # ship roughly monthly, and every image is pinned.
      DIUN_WATCH_SCHEDULE = "0 8 * * *";
      LOG_LEVEL = "info";
      TZ = config.time.timeZone;
    };
    environmentFiles = [config.sops.templates."diun.env".path];
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock:ro"
      "diun_data:/data"
    ];
    networks = ["proxy"];
  };
}
