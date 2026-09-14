{pkgs, ...}: let
  askpass = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
in {
  # No FIDO2 support; OpenSSH's agent below holds the YubiKey keys.
  services.gnome.gcr-ssh-agent.enable = false;

  programs.ssh = {
    startAgent = true;
    enableAskPassword = true;
    askPassword = askpass;
  };

  environment.systemPackages = [
    # uwsm/env finds the askpass helper with `command -v`; seahorse keeps it in libexec.
    (pkgs.writeShellScriptBin "ssh-askpass" ''exec ${askpass} "$@"'')
  ];

  homeManagerModules = [
    ./home.nix
  ];
}
