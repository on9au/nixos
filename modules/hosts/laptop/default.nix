# Install procedure lives in ./install.md. Disk layout mirrors DESKTOP-DYLAN
# (LUKS2 -> btrfs subvolumes) minus @games, and unlocks via TPM2 rather than
# FIDO2, so Secure Boot must be enrolled before the TPM enrollment is done.
{
  lib,
  pkgs,
  ...
}: {
  # nix-style: ignore-order
  imports = [
    # Hardware
    ./hardware.nix
    ../../hardware/drives/udisks.nix
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
    ../../system/envfs.nix
    ../../system/filesystems/btrfs.nix
    ../../system/filesystems/btrfs-snapshots.nix
    ../../system/network.nix
    ../../system/oomd.nix
    ../../system/tmpfs.nix

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
    ../../programs/services/keyring
    ../../programs/services/mullvad.nix
    ../../programs/services/piper-tts.nix
    ../../programs/services/power-profiles-daemon.nix
    ../../programs/services/ssh-agent
    ../../programs/services/sshd.nix
    ../../programs/services/tailscale.nix

    # Apps
    ../../programs/apps/actual.nix
    ../../programs/apps/discord.nix
    ../../programs/apps/spotify.nix
    ../../programs/apps/winapps
    ../../programs/apps/wireshark.nix

    # Shell and development
    ../../programs/development/claude-code
    ../../programs/development/neovim
    ../../programs/development/neovim/images
    ../../programs/development/neovim/lsp
    ../../programs/development/roblox
    ../../programs/development/toolchain
    ../../programs/tools
    ../../programs/tools/git
    ../../programs/tools/kitty
    ../../programs/tools/nh
    ../../programs/tools/nix-index
    ../../programs/tools/ssh
    ../../programs/tools/tmux
    ../../programs/tools/zsh
  ];

  networking.hostName = "LAPTOP-ON9AU";
  system.stateVersion = "26.11";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # TEMP(./nvme-vmd-stalls.md): erratum MTL016 on this machine's VMD loses NVMe
  # completion interrupts, and each one lost is a ~30s whole-machine freeze. The
  # patch delays 4us in vmd_irq() before demuxing, gated to 8086:7d0b alone.
  #
  # Patched in-tree rather than shipped as a module replacing vmd.ko, because
  # vmd is on the boot path (root sits behind it, see ./hardware.nix): the copy
  # in the initrd has to be the patched one and has to match the running kernel.
  # The price is that the kernel, and everything built against it (nvidia), stop
  # coming from the binary cache, so a kernel bump becomes a local compile.
  #
  # The series gate below, not `patch` succeeding, is what keeps this honest:
  # 7.3 took (1 << 6) for VMD_FEAT_USE_BIOS_INFO, the bit the 7.1 version of
  # this patch used for the quirk. A rebase can therefore alias the flag onto an
  # unrelated feature of the boot device's own controller and still apply
  # cleanly, so re-read the flag list by hand on every series bump.
  boot.kernelPatches = [
    {
      name = "vmd-mtl016";
      patch = assert lib.assertMsg (lib.versions.majorMinor pkgs.linuxPackages_latest.kernel.version == "7.3")
      "TEMP: linuxPackages_latest is ${pkgs.linuxPackages_latest.kernel.version}; re-port modules/hosts/laptop/vmd-mtl016.patch to that series, re-checking which VMD_FEAT bit is free, then widen this gate";
        ./vmd-mtl016.patch;
    }
  ];

  # TEMP(./nvme-vmd-stalls.md): backs up the patch above, which narrows the race
  # rather than closing it. Nothing can check this one; drop it once VMD is off
  # in the firmware.
  boot.kernelParams = [
    "nvme.use_threaded_interrupts=1"
    "nvme_core.default_ps_max_latency_us=0"
    "nvme_core.io_timeout=5"
  ];

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
