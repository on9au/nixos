{...}: {
  # The same policy as programs/services/sshd.nix, in Apple's sshd.
  services.openssh = {
    # Remote Login, Apple's job on 22; the one below replaces it.
    enable = false;

    extraConfig = ''
      AuthenticationMethods publickey
      KbdInteractiveAuthentication no
      PasswordAuthentication no
      PermitRootLogin no
      PubkeyAcceptedAlgorithms sk-ssh-ed25519@openssh.com
    '';
  };

  # Apple's com.openssh.sshd on 7456 instead: launchd hands sshd the socket,
  # so sshd_config's Port is never read.
  launchd.daemons.sshd.serviceConfig = {
    Program = "/usr/libexec/sshd-keygen-wrapper";
    ProgramArguments = ["/usr/sbin/sshd" "-i"];
    Sockets.Listeners.SockServiceName = "7456";
    StandardErrorPath = "/dev/null";
    inetdCompatibility.Wait = false;
  };
}
