{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    firefox
    loupe
    nautilus
    papers
    seahorse
  ];

  # Apps that save this replace the link with a real file; the next switch
  # moves it aside as .chezmoi-bak.
  xdg.configFile."mimeapps.list".source = config.lib.dotfiles.link ./mimeapps.list;
}
