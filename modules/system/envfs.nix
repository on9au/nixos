{...}: {
  # Fills /bin and /usr/bin from PATH, so `#!/bin/bash` scripts run. Left off
  # WSL, where NixOS-WSL manages /bin itself.
  services.envfs.enable = true;
}
