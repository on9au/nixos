# Needs Nix and Homebrew installed first, then:
#   sudo nix run nix-darwin -- switch --flake ~/nixos#MBP-DYLAN
{ config, lib, pkgs, inputs, ... }:

let
  user = config.system.primaryUser;
  home = config.system.primaryUserHome;
in
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    ../../modules/common/unfree.nix
    ../../modules/common/home-manager.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  networking.hostName = "MBP-DYLAN";

  system.primaryUser = "djpro";
  users.users.djpro = {
    home = "/Users/djpro";
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;

  unfree.allow = [ "claude-code" ];

  home-manager.users.djpro.imports = [ ../../home/darwin.nix ];

  # With the Determinate installer: nix.enable = false, and drop gc/optimise.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    interval = { Weekday = 0; Hour = 3; Minute = 0; };
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  fonts.packages = [ pkgs.nerd-fonts.fira-code ];

  # Casks rather than nixpkgs: Accessibility/Input Monitoring grants attach to
  # the app path, and a store path changes on every update.
  homebrew = {
    enable = true;
    onActivation.cleanup = "none";

    # Homebrew 6 aborts the whole bundle on an untrusted tap.
    taps = [
      { name = "felixkratz/formulae"; trusted = true; }
      { name = "nikitabobko/tap"; trusted = true; }
    ];

    brews = [
      { name = "felixkratz/formulae/sketchybar"; start_service = true; }
      { name = "felixkratz/formulae/borders"; start_service = true; }
    ];

    casks = [
      "nikitabobko/tap/aerospace"
      "ghostty"
      "karabiner-elements"
      "raycast"
      "orion"
    ];
  };

  # Reasoning for these is in the README under "System defaults" and "Keyboard".
  system.defaults = {
    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.15;
      show-recents = false;
      tilesize = 40;
      mru-spaces = false;
      expose-group-apps = false;

      # 1 = off, 12 = Notification Centre.
      wvous-bl-corner = 1;
      wvous-br-corner = 1;
      wvous-tl-corner = 1;
      wvous-tr-corner = 12;
    };

    NSGlobalDomain = {
      # 15 ms ticks: 30 ms repeat, 255 ms delay (hypr/input.lua has 40/s, 250 ms).
      KeyRepeat = 2;
      InitialKeyRepeat = 17;
      ApplePressAndHoldEnabled = false;

      _HIHideMenuBar = true;
      NSAutomaticWindowAnimationsEnabled = false;
      AppleShowAllExtensions = true;
      AppleInterfaceStyle = "Dark";

      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;

      NSNavPanelExpandedStateForSaveMode = true;
      PMPrintingExpandedStateForPrint = true;

      "com.apple.mouse.tapBehavior" = 1;
    };

    finder = {
      AppleShowAllFiles = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      FXPreferredViewStyle = "Nlsv";
      _FXSortFoldersFirst = true;
      FXDefaultSearchScope = "SCcf";
      NewWindowTarget = "Home";
      FXEnableExtensionChangeWarning = false;
    };

    screencapture = {
      location = "${home}/Pictures/Screenshots";
      type = "png";
      disable-shadow = true;
    };

    trackpad.Clicking = true;

    hitoolbox.AppleFnUsageType = "Change Input Source";

    CustomUserPreferences = {
      "com.apple.dock".workspaces-auto-swoosh = false;
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
    };
  };

  # Symbolic hotkeys use -dict-add because CustomUserPreferences would replace
  # the whole dictionary. 60 (previous input source) moves to hyper+Space to
  # free Ctrl+Space for Raycast; 61 is disabled.
  system.activationScripts.postActivation.text = ''
    sudo --user=${user} -- mkdir -p ${home}/Pictures/Screenshots

    sudo --user=${user} -- defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 \
      '<dict><key>enabled</key><true/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>1835008</integer></array></dict></dict>'
    sudo --user=${user} -- defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 \
      '<dict><key>enabled</key><false/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>786432</integer></array></dict></dict>'

    sudo --user=${user} -- defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

    _activate=/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings
    [ -x "$_activate" ] && sudo --user=${user} -- "$_activate" -u >/dev/null 2>&1 || true
  '';

  system.stateVersion = 6;
}
