{...}: {
  # The Secret Service that browsers, Electron apps and git-credential-libsecret
  # ask for by name. Not kwallet: it registers only
  # org.kde.secretservicecompat, which nothing outside KDE looks for.
  services.gnome.gnome-keyring.enable = true;
  # Only PAM has the login password to unlock it with, and greetd
  # authenticates through its own PAM service. A new keyring appears after the
  # next full login, not after the switch.
  security.pam.services.greetd.enableGnomeKeyring = true;
  # Re-key the keyring when the login password changes.
  security.pam.services.passwd.enableGnomeKeyring = true;

  homeManagerModules = [
    ./home.nix
  ];
}
