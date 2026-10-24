{
  config,
  pkgs,
  ...
}: {
  services.openssh = {
    enable = true;

    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Ghostty (the macbook's terminal) sends TERM=xterm-ghostty; without its
  # terminfo, zsh, tmux and nvim draw garbage over ssh.
  environment.systemPackages = [pkgs.ghostty.terminfo];

  # openFirewall defaults on, so services.openssh.ports opens itself.

  # With password auth off, an empty key list is a locked door. Fail the build
  # rather than find out after the switch, from the console.
  assertions = [
    {
      assertion = config.users.users.${config.primaryUser}.openssh.authorizedKeys.keys != [];
      message = "programs/services/sshd.nix: ${config.primaryUser} has no authorizedKeys and password auth is disabled -- this switch would lock you out.";
    }
  ];
}
