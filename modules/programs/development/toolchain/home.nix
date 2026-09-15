{pkgs, ...}: {
  home.packages = with pkgs; [
    fnm
    nodejs
    pnpm
  ];
}
