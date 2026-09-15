{pkgs, ...}: {
  # Yubico Authenticator's OATH codes go over CCID; FIDO2 ssh keys don't need this.
  services.pcscd.enable = true;

  environment.systemPackages = with pkgs; [
    age
    age-plugin-yubikey
    sops
    yubikey-manager
    yubioath-flutter
  ];

  homeManagerModules = [
    ./home.nix
  ];
}
