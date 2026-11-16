{
  lib,
  pkgs,
  ...
}: let
  # TEMP(nixpkgs#587533): glances 4.5.7 needs python-jose, which nixpkgs now
  # marks insecure and refuses to evaluate; 4.5.9 uses pyjwt instead.
  glances = assert lib.assertMsg (lib.versionOlder pkgs.glances.version "4.5.9")
  "TEMP: nixpkgs has glances ${pkgs.glances.version}; drop the glances override in programs/tools/home.nix";
    pkgs.glances.overridePythonAttrs (old: {
      version = "4.5.9";
      src = pkgs.fetchFromGitHub {
        owner = "nicolargo";
        repo = "glances";
        tag = "v4.5.9";
        hash = "sha256-CvT9GQ29xXTVxC7V2nGmfDhHLsAtF61+XMMLG8cmHww=";
      };
      dependencies =
        builtins.filter (dep: (dep.pname or "") != "python-jose") old.dependencies
        ++ [pkgs.python3Packages.pyjwt];
      nativeCheckInputs = old.nativeCheckInputs ++ [pkgs.python3Packages.pysmart];
      # Starts a server and queries it after a fixed 5s sleep; on a loaded
      # builder the first queries arrive before it is listening.
      disabledTestPaths = old.disabledTestPaths ++ ["tests/test_restful.py"];
    });
in {
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

  programs.btop = {
    enable = true;
    settings.color_theme = "catppuccin_mocha";
  };

  # Not programs.btop.themes, which writes a store path string as the file's text.
  xdg.configFile."btop/themes/catppuccin_mocha.theme".source = "${pkgs.catppuccin.override {variant = "mocha";}}/btop/catppuccin_mocha.theme";

  # Also aliases ls, ll, la and lt.
  programs.eza = {
    enable = true;
    git = true;
    icons = "auto";
  };

  programs.fzf.enable = true;

  # Enabled rather than just installed for the `y` wrapper, which leaves the
  # shell in the directory yazi was quit in.
  programs.yazi.enable = true;

  programs.zoxide.enable = true;
}
