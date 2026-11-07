{
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = [
    # Vencord built in; its installer can't patch a store path.
    (pkgs.discord.override {
      withVencord = true;
      withTTS = true;
      # TEMP(nixpkgs#584169): 1.15.13 leaves the window blank after Discord's
      # rspack update.
      vencord = assert lib.assertMsg (lib.versionOlder pkgs.vencord.version "1.15.16")
      "TEMP: nixpkgs has vencord ${pkgs.vencord.version}; drop the vencord override in programs/apps/discord.nix";
        pkgs.vencord.overrideAttrs (finalAttrs: _: {
          version = "1.15.16";
          src = pkgs.fetchFromGitHub {
            owner = "Vendicated";
            repo = "Vencord";
            tag = "v${finalAttrs.version}";
            hash = "sha256-aUJubLJpyLAZWiOezqFxPY6oVPgWVPQpajFqrJvrO9U=";
          };
          patches = [];
          postPatch = "";
          pnpmDeps = pkgs.fetchPnpmDeps {
            pname = finalAttrs.pname;
            src = finalAttrs.src;
            pnpm = pkgs.pnpm_11;
            fetcherVersion = 4;
            hash = "sha256-HS8uZNepvDefjrsG3buVLFCVv7sHvazcwdpcT3EQ/78=";
          };
        });
    })
  ];
}
