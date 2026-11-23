{
  den.aspects.macos.defaults.darwin = {
    system.defaults = {
      dock = {
        autohide = true;
        show-recents = false;
        mru-spaces = false;
        tilesize = 48;

        persistent-apps = [
          "/Applications/WeChat.app"
          "/Applications/Helium.app"
        ];
      };

      finder = {
        AppleShowAllExtensions = true;
        FXEnableExtensionChangeWarning = false;
        ShowPathbar = true;
        ShowStatusBar = true;
        FXDefaultSearchScope = "SCcf";
        FXPreferredViewStyle = "Nlsv";
        _FXShowPosixPathInTitle = true;
      };

      NSGlobalDomain = {
        AppleInterfaceStyleSwitchesAutomatically = true;
        AppleICUForce24HourTime = true;
        AppleShowAllExtensions = true;
        ApplePressAndHoldEnabled = false;
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        PMPrintingExpandedStateForPrint = true;
        PMPrintingExpandedStateForPrint2 = true;
      };

      trackpad.Clicking = true;

      loginwindow.GuestEnabled = false;

      WindowManager.EnableStandardClickToShowDesktop = false;
      WindowManager.GloballyEnabled = false;
      # Sequoia's built-in tiling fights with AeroSpace.
      WindowManager.EnableTilingByEdgeDrag = false;
      WindowManager.EnableTopTilingByEdgeDrag = false;
      WindowManager.EnableTilingOptionAccelerator = false;
    };
  };
}
