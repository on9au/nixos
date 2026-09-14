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
      wl-clipboard
    ];
}
