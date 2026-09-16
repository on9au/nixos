{
  config,
  pkgs,
  ...
}: {
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

  # `cargo install` target; zshenv only adds it when rustup's ~/.cargo/env exists.
  home.sessionPath = ["${config.home.homeDirectory}/.cargo/bin"];

  home.sessionVariables = {
    # Apphosts from `dotnet build` look for the runtime here, not next to `dotnet`.
    DOTNET_ROOT = "${pkgs.dotnet-sdk}/share/dotnet";
    # nixpkgs' rustc has no rust-src component for rust-analyzer to find std in.
    RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
  };
}
