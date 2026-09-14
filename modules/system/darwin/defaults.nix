{config, ...}: let
  user = config.system.primaryUser;
  home = config.system.primaryUserHome;
in {
  # Reasoning for these is in modules/hosts/macbook/README.md.
  system.defaults = {
    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.15;
      expose-group-apps = false;
      mru-spaces = false;
      show-recents = false;
      tilesize = 40;

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
      AppleInterfaceStyle = "Dark";
      AppleShowAllExtensions = true;
      NSAutomaticWindowAnimationsEnabled = false;

      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;

      NSNavPanelExpandedStateForSaveMode = true;
      PMPrintingExpandedStateForPrint = true;

      "com.apple.mouse.tapBehavior" = 1;
    };

    finder = {
      _FXSortFoldersFirst = true;
      AppleShowAllFiles = true;
      FXDefaultSearchScope = "SCcf";
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv";
      NewWindowTarget = "Home";
      ShowPathbar = true;
      ShowStatusBar = true;
    };

    screencapture = {
      disable-shadow = true;
      location = "${home}/Pictures/Screenshots";
      type = "png";
    };

    trackpad.Clicking = true;

    hitoolbox.AppleFnUsageType = "Change Input Source";

    CustomUserPreferences = {
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      "com.apple.dock".workspaces-auto-swoosh = false;
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
}
