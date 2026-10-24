# Not a module: ai/ and up-import/ import it for the actual-session script.
{
  config,
  pkgs,
}:
pkgs.writeShellApplication {
  name = "actual-session";
  runtimeInputs = with pkgs; [
    config.virtualisation.docker.package
    coreutils
    gnugrep
    gnused
    systemd
  ];
  text = builtins.readFile ./session.sh;
}
