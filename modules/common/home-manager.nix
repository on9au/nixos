{ inputs, ... }:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };

    # chezmoi left real files where the links go; the first switch moves them aside.
    backupFileExtension = "chezmoi-bak";

    users.djpro.imports = [ ../../home ];
  };
}
