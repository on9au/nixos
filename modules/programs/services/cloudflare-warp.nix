{pkgs, ...}: {
  services.cloudflare-warp.enable = true;

  # The tray app has to run from the unit the package ships -- see
  # ./cloudflare-warp.md. systemd.packages links it, and brings the package's
  # own warp-svc.service along with it; that is a second copy of the daemon
  # services.cloudflare-warp already runs, so it is masked.
  systemd.packages = [pkgs.cloudflare-warp];
  systemd.services.warp-svc.enable = false;

  # systemd.packages links a unit but ignores its [Install], so the tray would
  # never start on its own. asDropin keeps the packaged unit as the base.
  systemd.user.services.warp-taskbar = {
    overrideStrategy = "asDropin";
    wantedBy = ["graphical-session.target"];
  };
}
