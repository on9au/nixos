{
  description = "Java project - a JDK and javac, no build file";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {nixpkgs, ...}: let
    forEachSystem = f:
      nixpkgs.lib.genAttrs ["aarch64-darwin" "x86_64-linux"]
      (system: f nixpkgs.legacyPackages.${system});
  in {
    devShells = forEachSystem (pkgs: let
      # no correto on darwin nixos
      jdk17 =
        if pkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.corretto17
        then pkgs.corretto17
        else pkgs.temurin-bin-17;
    in {
      default = pkgs.mkShell {
        packages = [
          jdk17 # `javac` and `java`
          pkgs.google-java-format # formatter
          pkgs.jdt-language-server # jdtls lsp
        ];

        # javac and java come off PATH, but anything that resolves a JDK through
        # JAVA_HOME (IntelliJ, most wrapper scripts) would otherwise find the
        # login shell's 25 rather than the version this project is written for.
        JAVA_HOME = "${jdk17}";
      };
    });
  };
}
