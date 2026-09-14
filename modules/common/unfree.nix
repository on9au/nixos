# allowUnfreePredicate can only be defined once, so modules add names here.
{ config, lib, ... }:

{
  options.unfree.allow = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };

  config.nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) config.unfree.allow;
}
