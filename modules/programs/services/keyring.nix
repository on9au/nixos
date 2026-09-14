{...}: {
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;
  # Re-key the keyring when the login password changes.
  security.pam.services.passwd.enableGnomeKeyring = true;
}
