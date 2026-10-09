{
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs;
    [
      _7zz
      cbonsai
      dnsutils
      duf
      exiftool
      fastfetch
      glances
      iperf3
      jq
      less
      nix-output-monitor
      pandoc
      sl
      smartmontools
      tldr
      tree
      unrar
      unzip
      upx
      zip
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      hwinfo
      inxi
      whois
      wkhtmltopdf
      wl-clipboard
    ];

  programs.bat = {
    enable = true;
    config.theme = "Catppuccin Mocha";
    extraPackages = with pkgs.bat-extras; [
      batdiff
      batgrep
      batman
    ];
    themes."Catppuccin Mocha" = {
      src = pkgs.catppuccin.override {variant = "mocha";};
      file = "bat/Catppuccin Mocha.tmTheme";
    };
  };

  programs.fzf.enable = true;

  # Enabled rather than just installed for the `y` wrapper, which leaves the
  # shell in the directory yazi was quit in.
  programs.yazi.enable = true;

  programs.zoxide.enable = true;
}
