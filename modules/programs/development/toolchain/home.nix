{
  config,
  lib,
  pkgs,
  ...
}: let
  # No Corretto build for macOS in nixpkgs.
  jdk17 =
    if lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.corretto17
    then pkgs.corretto17
    else pkgs.temurin-bin-17;
in {
  home.packages = with pkgs; [
    cargo
    clippy
    dotnet-sdk
    fnm
    nodejs
    pnpm
    rustc
    rustfmt
  ];

  # Stable paths for per-project JDKs: nvim's java.lua, IntelliJ, and .envrc
  # files point here instead of at store paths.
  home.file = {
    ".jdks/17".source = jdk17;
    ".jdks/25".source = pkgs.temurin-bin-25;
  };

  programs.java = {
    enable = true;
    package = pkgs.temurin-bin-25;
  };

  # `cargo install` target; zshenv only adds it when rustup's ~/.cargo/env exists.
  home.sessionPath = ["${config.home.homeDirectory}/.cargo/bin"];

  home.sessionVariables = {
    # Apphosts from `dotnet build` look for the runtime here, not next to `dotnet`.
    DOTNET_ROOT = "${pkgs.dotnet-sdk}/share/dotnet";
    # nixpkgs' rustc has no rust-src component for rust-analyzer to find std in.
    RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
  };
}
