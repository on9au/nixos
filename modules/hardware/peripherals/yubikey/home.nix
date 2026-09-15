{
  config,
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs;
    [
      age-plugin-yubikey
      libfido2
      sops
      ssh-to-age
    ]
    # Apple's ssh has no FIDO2 provider.
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      openssh
    ];

  # sops looks under ~/Library/Application Support on macOS; one path on every
  # machine means the same keys.txt copies anywhere.
  home.sessionVariables.SOPS_AGE_KEY_FILE = "${config.xdg.configHome}/sops/age/keys.txt";
}
