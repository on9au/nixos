{osConfig, ...}: {
  # programs.ssh.startAgent only exports SSH_AUTH_SOCK to shells, not the user manager.
  systemd.user.sessionVariables = {
    SSH_ASKPASS = osConfig.programs.ssh.askPassword;
    SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-agent";
  };
}
