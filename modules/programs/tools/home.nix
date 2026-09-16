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
      fzf
      glances
      iperf3
      jq
      less
      pandoc
      sl
      smartmontools
      tldr
      tree
      unrar
      unzip
      upx
      yazi
      zip
      zoxide
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      hwinfo
      inxi
      whois
      wkhtmltopdf
      wl-clipboard
    ];
}
