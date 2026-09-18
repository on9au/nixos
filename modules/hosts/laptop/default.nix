# Install procedure lives in ./install.md. Disk layout mirrors DESKTOP-DYLAN
# (LUKS2 -> btrfs subvolumes) minus @games, and unlocks via TPM2 rather than
# FIDO2, so Secure Boot must be enrolled before the TPM enrollment is done.
{lib, ...}: {
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
    ../../system/boot/lanzaboote.nix
    ../../system/filesystems/btrfs.nix
    ../../system/filesystems/btrfs-snapshots.nix
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
    ../../programs/services/piper-tts.nix
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
    ../../programs/development/neovim/lsp
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

  # systemd in initrd - required for the TPM2 LUKS unlock below.
  boot.initrd.systemd.enable = true;

  # TPM2 is the only routine unlock. The passphrase in keyslot 0 stays as the
  # break-glass path and is deliberately never removed: a firmware update that
  # moves PCR 7 invalidates the TPM binding, and without the passphrase that is
  # unrecoverable. Enroll only *after* Secure Boot is on, see ./install.md.
  boot.initrd.luks.devices."cryptroot".crypttabExtraOpts = ["tpm2-device=auto"];

  swapDevices = [{device = "/swap/swapfile";}];

  # lanzaboote ignores boot.loader.systemd-boot.* - it mkForce-disables that
  # module and writes loader.conf from these settings instead. Setting
  # `boot.loader.systemd-boot.rebootForBitlocker` here would silently do
  # nothing, so the raw loader.conf key is what gets set.
  #
  # reboot-for-bitlocker makes sd-boot set EFI BootNext and reboot when the
  # Windows entry is chosen, instead of chainloading it. Windows then boots as
  # though it were booted directly, so its TPM measurements match what
  # BitLocker sealed against and C:/G: do not drop into recovery.
  boot.lanzaboote.settings.reboot-for-bitlocker = "yes";

  # The ESP is 420 MiB and shared with Windows + Dell, leaving roughly 310 MiB
  # for us. A signed UKI bundles kernel and initrd into one file, ~90 MiB here,
  # so the shared default of 10 would overrun the partition. Check
  # `df -h /boot` after the first few rebuilds and drop to 2 if it gets tight.
  boot.lanzaboote.configurationLimit = lib.mkForce 3;

  # Nested subvolumes (/nix, /home, /swap) are not captured by a snapshot of
  # /, so /home is taken separately. btrbk won't create the target dirs.
  services.btrbk.instances.default.settings.subvolume = {
    "/".snapshot_dir = "/.snapshots/root";
    "/home".snapshot_dir = "/.snapshots/home";
  };

  systemd.tmpfiles.settings."btrbk-snapshot-dirs" = {
    "/.snapshots/root".d = {};
    "/.snapshots/home".d = {};
  };

  hardware.nvidia.prime = {
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  homeManagerModules = [
    {home.stateVersion = "26.05";}
  ];
}
