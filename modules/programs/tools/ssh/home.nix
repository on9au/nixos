{...}: {
  programs.ssh = {
    enable = true;

    # This pin warns on every build unless the old implicit defaults are
    # turned off and restated explicitly.
    enableDefaultConfig = false;

    settings = {
      "*" = {
        IdentityFile = "~/.ssh/id_ed25519_sk_rk";
        IdentitiesOnly = true;
      };

      jia = {
        HostName = "jia-opena0.tailc7b8fd.ts.net";
        Port = 7456;
        User = "opena0";
      };
    };
  };
}
