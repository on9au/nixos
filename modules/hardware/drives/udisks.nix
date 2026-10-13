{...}: {
  services.udisks2.enable = true;

  # Nautilus only lists and mounts udisks2 volumes through gvfs's volume monitor.
  services.gvfs.enable = true;

  # The kernel mounts NTFS on its own; this adds the mkfs and fsck tools.
  boot.supportedFilesystems = ["ntfs"];
}
