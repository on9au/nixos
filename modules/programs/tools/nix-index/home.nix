{inputs, ...}: {
  imports = [
    inputs.nix-index-database.homeModules.nix-index
  ];

  # A prebuilt index, so a missing command names the package that has it, and
  # `, <command>` runs it without installing anything.
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;
}
