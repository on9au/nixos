{...}: {
  security.pam.services.sudo_local = {
    # Without pam_reattach, Touch ID fails inside tmux, which runs outside the
    # login session.
    reattach = true;
    touchIdAuth = true;
  };
}
