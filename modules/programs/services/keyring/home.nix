{pkgs, ...}: {
  # Monash filters SSH to git.infotech off-campus, so it is HTTPS with a PAT.
  # gitFull is the only package that builds the libsecret helper, which puts the
  # PAT in the keyring above rather than in a plaintext ~/.git-credentials.
  programs.git.settings.credential."https://git.infotech.monash.edu.au".helper = "${pkgs.gitFull}/bin/git-credential-libsecret";
}
