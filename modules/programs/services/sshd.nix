{config, ...}: {
  services.openssh = {
    enable = true;

    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

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
