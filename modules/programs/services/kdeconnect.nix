{...}: {
  # Pairing, with the phone app open on the same network:
  #   kdeconnect-cli --refresh && kdeconnect-cli --list-available
  #   kdeconnect-cli --pair -d <device-id>
  programs.kdeconnect.enable = true;
}
