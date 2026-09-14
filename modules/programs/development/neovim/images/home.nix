{pkgs, ...}: {
  # Snacks.image and diagram.nvim's rendering chain; needs a kitty-graphics terminal.
  home.packages = with pkgs; [
    ghostscript
    imagemagick
    mermaid-cli
    tectonic
  ];
}
