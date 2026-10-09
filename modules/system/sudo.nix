{...}: {
  # Ask once per 30 minutes rather than 5, and echo `*` while typing.
  security.sudo.extraConfig = ''
    Defaults pwfeedback
    Defaults timestamp_timeout=30
  '';
}
