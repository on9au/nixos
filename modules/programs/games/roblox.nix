{...}: {
  # Roblox and Roblox Studio. Installed from Flathub by nix-flatpak when the system switches.
  services.flatpak = {
    enable = true;
    packages = ["org.vinegarhq.Sober" "org.vinegarhq.Vinegar"];
  };
}
