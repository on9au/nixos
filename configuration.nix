{ config, lib, pkgs, ... }:

let
  greeterConfig = pkgs.replaceVars ./greetd/hyprland.lua {
    regreet = "${config.services.displayManager.regreet.package}/bin/regreet";
  };
in
{
  imports = [ ./hardware-configuration.nix ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ 
      "posy-cursors"
      "claude-code"
    ];

  # Bootloader — ESP is shared with EndeavourOS
  boot.loader.systemd-boot.enable = lib.mkForce false;
  
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    configurationLimit = 10;
    settings.console-mode = "max";
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 10;

  # systemd in initrd — required for FIDO2 LUKS unlock later
  boot.initrd.systemd.enable = true;
  boot.initrd.luks.devices."cryptroot".crypttabExtraOpts = [ "fido2-device=auto" ];

  # Swap
  swapDevices = [ { device = "/swap/swapfile"; } ];
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;

  services.btrfs.autoScrub.enable = true;
  services.btrfs.autoScrub.fileSystems = [ "/" ];

  networking.hostName = "DESKTOP-DYLAN";
  networking.networkmanager.enable = true;
  time.timeZone = "Australia/Melbourne";
  i18n.defaultLocale = "en_AU.UTF-8";

  # AMD RX 9070 XT
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Users
  users.users.djpro = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };

  environment.systemPackages = with pkgs; [
    vim wget curl pciutils usbutils
    zsh starship tmux fzf git gh chezmoi openssh less jq unzip
    neovim tree-sitter ripgrep fd lazygit sqlite
    gcc gnumake clang
    wl-clipboard fnm
    sbctl

    fuzzel swaynotificationcenter hyprlock hypridle hyprpolkitagent
    hyprshot hyprpicker cliphist wtype bemoji waybar awww
    kitty playerctl pavucontrol brightnessctl htop
    kdePackages.ksshaskpass libfido2
    imagemagick ghostscript tectonic mermaid-cli
    firefox
    nautilus
    claude-code
  ];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [ fcitx5-mozc qt6Packages.fcitx5-chinese-addons fcitx5-gtk ];
  };

  programs.ssh = {
    startAgent = true;
    enableAskPassword = true;
    askPassword = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
  };

  programs.zsh.enable = true;

  programs.hyprland.enable = true;
  programs.hyprland.withUWSM = true;

  xdg.portal.enable = true;
  xdg.portal.extraPortals = with pkgs; [
    xdg-desktop-portal-gtk
  ];

  services.displayManager.regreet = {
    enable = true;

    font = { name = "Noto Sans"; size = 12; };
    theme = { package = pkgs.kdePackages.breeze-gtk; name = "Breeze"; };


    settings = {
      background = { path = ./assets/regreet-wallpaper.jpg; fit = "Cover"; };
      GTK = {
        application_prefer_dark_theme = true;
      };
      commands = {
        reboot = [ "systemctl" "reboot" ];
        poweroff = [ "systemctl" "poweroff" ];
      };
    };

    cursorTheme = {
      package = pkgs.posy-cursors;
      name = "Posy_Cursor_Black";
    };
  };

  services.greetd.settings.default_session.command = lib.mkForce
    "${pkgs.hyprland}/bin/Hyprland --config ${greeterConfig}";

  security.pam.services.greetd.enableGnomeKeyring = true;

  programs.hyprlock.enable = true;
  services.hypridle.enable = true;

  security.polkit.enable = true;
  security.rtkit.enable = true;

  programs.nix-ld.enable = true;

  programs.kdeconnect.enable = true;

  services.power-profiles-daemon.enable = true;

  services.gnome.gnome-keyring.enable = true;
  services.gnome.gcr-ssh-agent.enable = false;

  fonts.packages = with pkgs; [ nerd-fonts.fira-code noto-fonts-color-emoji noto-fonts-cjk-sans noto-fonts-cjk-serif ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
