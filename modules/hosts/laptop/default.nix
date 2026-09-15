# Still on Arch. Generate the hardware config during the install, then git add it:
#   nixos-generate-config --root /mnt --show-hardware-config > modules/hosts/laptop/hardware.nix
{...}: {
  # nix-style: ignore-order
  imports = [
    # Hardware
    ./hardware.nix
    ../../hardware/firmware/fwupd.nix
    ../../hardware/gpu/intel.nix
    ../../hardware/gpu/nvidia-prime.nix
    ../../hardware/peripherals/bluetooth.nix
    ../../hardware/peripherals/keyd.nix
    ../../hardware/peripherals/printing.nix
    ../../hardware/peripherals/tablet.nix
    ../../hardware/peripherals/yubikey
    ../../hardware/power/laptop.nix

    # System
    ../../system
    ../../system/boot/systemd-boot.nix
    ../../system/network.nix

    # Users
    ../../users/djpro
    ../../home-manager

    # Desktop
    ../../programs/desktop/catppuccin
    ../../programs/desktop/fonts.nix
    ../../programs/desktop/fuzzel
    ../../programs/desktop/general
    ../../programs/desktop/greetd
    ../../programs/desktop/hyprland
    ../../programs/desktop/input-method.nix
    ../../programs/desktop/pipewire.nix
    ../../programs/desktop/swaync
    ../../programs/desktop/waybar

    # Services
    ../../programs/services/kdeconnect.nix
    ../../programs/services/keyring.nix
    ../../programs/services/mullvad.nix
    ../../programs/services/power-profiles-daemon.nix
    ../../programs/services/ssh-agent
    ../../programs/services/tailscale.nix

    # Apps
    ../../programs/apps/discord.nix
    ../../programs/apps/spotify.nix
    ../../programs/apps/winapps

    # Shell and development
    ../../programs/development/claude-code
    ../../programs/development/neovim
    ../../programs/development/neovim/images
    ../../programs/development/toolchain
    ../../programs/tools
    ../../programs/tools/git
    ../../programs/tools/kitty
    ../../programs/tools/nh
    ../../programs/tools/ssh
    ../../programs/tools/tmux
    ../../programs/tools/zsh
  ];

  networking.hostName = "LAPTOP-ON9AU";
  system.stateVersion = "26.11";

  # VMD stall stopgap, see ./nvme-vmd-stalls.md. Drop once VMD is off in firmware.
  boot.kernelParams = [
    "nvme.use_threaded_interrupts=1"
    "nvme_core.default_ps_max_latency_us=0"
    "nvme_core.io_timeout=5"
  ];

  hardware.nvidia.prime = {
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  homeManagerModules = [
    {home.stateVersion = "26.05";}
  ];
}
