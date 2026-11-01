{
  config,
  pkgs,
  ...
}: let
  user = config.users.users.${config.primaryUser};
in {
  # The same policy is in system/darwin/sshd.nix for the Mac.
  services.openssh = {
    enable = true;
    # Tailscale only; a host that also takes the LAN opens it itself.
    openFirewall = false;
    ports = [7456];

    settings = {
      AuthenticationMethods = "publickey";
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      # YubiKey FIDO2 keys only: a plain key in an authorized_keys is refused.
      PubkeyAcceptedAlgorithms = "sk-ssh-ed25519@openssh.com";
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [7456];

  # Ghostty (the macbook's terminal) sends TERM=xterm-ghostty; without its
  # terminfo, zsh, tmux and nvim draw garbage over ssh.
  environment.systemPackages = [pkgs.ghostty.terminfo];

  # With password auth off, an empty key list is a locked door. Fail the build
  # rather than find out after the switch, from the console.
  assertions = [
    {
      assertion = user.openssh.authorizedKeys.keys != [] || user.openssh.authorizedKeys.keyFiles != [];
      message = "programs/services/sshd.nix: ${config.primaryUser} has no authorizedKeys and password auth is disabled -- this switch would lock you out.";
    }
  ];
}
