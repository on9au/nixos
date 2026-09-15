{
  config,
  pkgs,
  ...
}: {
  sops.secrets."liveness/url" = {};

  # Uptime Kuma dies with the box, so an off-box dead-man switch notices when
  # these pings stop. Deliberately dumb: "up, with outbound network", nothing more.
  systemd.services.homelab-liveness = {
    description = "Homelab liveness heartbeat";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    path = [pkgs.curl];
    script = ''
      curl -fsS -m 20 --retry 3 -o /dev/null "$(cat ${config.sops.secrets."liveness/url".path})"
    '';
    serviceConfig.Type = "oneshot";
  };

  systemd.timers.homelab-liveness = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
    };
  };
}
