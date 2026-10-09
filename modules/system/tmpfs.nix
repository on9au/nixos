{...}: {
  # Nix builds in /nix/var/nix/builds, not /tmp, so big builds don't land in RAM.
  boot.tmp.useTmpfs = true;
}
