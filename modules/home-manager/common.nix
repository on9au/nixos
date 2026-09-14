{
  config,
  inputs,
  lib,
  ...
}: {
  # Links point into the checkout rather than the store, so edits to a
  # module's config files apply without a rebuild.
  options.dotfiles.root = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/nixos";
  };

  config.lib.dotfiles.link = path:
    config.lib.file.mkOutOfStoreSymlink
    (config.dotfiles.root + lib.removePrefix (toString inputs.self) (toString path));
}
