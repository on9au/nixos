{pkgs, ...}: {
  fonts.packages = with pkgs; [
    caladea # metric-compatible Cambria for Office files
    carlito # metric-compatible Calibri for Office files
    corefonts # Arial/Times/Verdana, for documents and sites that assume them
    dejavu_fonts
    liberation_ttf # metric-compatible Arial/Times/Courier for LibreOffice
    nerd-fonts.fira-code
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    open-sans
    ttf_bitstream_vera
  ];
}
