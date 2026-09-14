{
  config,
  inputs,
  ...
}: {
  home-manager = {
    extraSpecialArgs = {inputs = inputs;};

    # chezmoi left real files where the links go; the first switch moves them aside.
    backupFileExtension = "chezmoi-bak";

    useGlobalPkgs = true;
    useUserPackages = true;

    users.${config.primaryUser}.imports =
      [
        ./common.nix
      ]
      ++ config.homeManagerModules;
  };
}
