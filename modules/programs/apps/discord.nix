{pkgs, ...}: {
  environment.systemPackages = [
    # Vencord built in; its installer can't patch a store path.
    (pkgs.discord.override {withVencord = true;})
  ];
}
