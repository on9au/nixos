{...}: {
  # Roblox and Roblox Studio. Installed from Flathub by nix-flatpak when the system switches.
  services.flatpak = {
    enable = true;
    packages = ["org.vinegarhq.Sober" "org.vinegarhq.Vinegar"];
    # Discord rich presence: the sandbox can't see Discord's IPC socket otherwise.
    overrides."org.vinegarhq.Sober".Context.filesystems = [
      "xdg-run/app/com.discordapp.Discord:create"
      "xdg-run/discord-ipc-0"
    ];
  };
}
