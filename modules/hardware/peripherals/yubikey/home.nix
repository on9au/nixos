{
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs;
    [
      libfido2
    ]
    # Apple's ssh has no FIDO2 provider.
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      openssh
    ];
}
