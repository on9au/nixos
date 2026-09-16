{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    loupe
    nautilus
    papers
    seahorse
  ];

  # Apps that save this replace the link with a real file; the next switch
  # moves it aside as .chezmoi-bak.
  xdg.configFile."mimeapps.list".source = config.lib.dotfiles.link ./mimeapps.list;

  programs.firefox = {
    enable = true;

    # Adopt the profile Firefox already created. Without path/storeId,
    # home-manager writes a profiles.ini pointing at a fresh empty "default"
    # and the real profile is orphaned; storeId matches its Profile Groups db.
    profiles.default = {
      path = "52sifgke.default";
      storeId = "5ff869d2";
    };

    betterfox = {
      enable = true;
      profiles.default = {
        enableAllSections = true;

        settings = {
          smoothfox = {
            natural-smooth-scrolling-v3.enable = true;
          };
        };
      };
    };
  };
}
