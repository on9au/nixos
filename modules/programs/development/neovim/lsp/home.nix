{pkgs, ...}: {
  # Everything the LazyVim extras expect on PATH; Mason is disabled.
  home.packages = with pkgs; [
    alejandra
    bash-language-server
    clang-tools # clangd
    csharpier
    docker-compose-language-service
    dockerfile-language-server
    fantomas
    fsautocomplete
    google-java-format
    hadolint
    jdt-language-server
    lua-language-server
    markdown-toc
    markdownlint-cli2
    marksman
    netcoredbg
    nil
    omnisharp-roslyn
    pyright
    ruff
    rust-analyzer
    shellcheck
    shfmt
    sqlfluff
    statix
    stylua
    taplo
    vscode-langservers-extracted # jsonls
    vtsls
    yaml-language-server
  ];
}
