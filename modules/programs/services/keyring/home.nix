{pkgs, ...}: {
  # Monash filters SSH to git.infotech off-campus, so it is HTTPS with a PAT.
  # gitFull is the only package that builds the libsecret helper, which puts the
  # PAT in the keyring above rather than in a plaintext ~/.git-credentials.
  # The host has a .edu.au alias on the same address, but git matches this key
  # as a literal string and every FIT remote uses the .edu spelling.
  programs.git.settings.credential."https://git.infotech.monash.edu".helper = "${pkgs.gitFull}/bin/git-credential-libsecret";
}
