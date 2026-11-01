{...}: {
  programs.ssh = {
    enable = true;

    # This pin warns on every build unless the old implicit defaults are
    # turned off and restated explicitly.
    enableDefaultConfig = false;

    # Every host's sshd is on 7456 (programs/services/sshd.nix,
    # system/darwin/sshd.nix).
    settings = {
      "*" = {
        IdentityFile = "~/.ssh/id_ed25519_sk_rk";
        IdentitiesOnly = true;
      };

      desktop = {
        HostName = "desktop-dylan.tailc7b8fd.ts.net";
        Port = 7456;
        User = "djpro";
      };

      jia = {
        HostName = "jia-opena0.tailc7b8fd.ts.net";
        Port = 7456;
        User = "opena0";
      };

      laptop = {
        HostName = "laptop-on9au.tailc7b8fd.ts.net";
        Port = 7456;
        User = "djpro";
      };

      mbp = {
        HostName = "mbp-dylan.tailc7b8fd.ts.net";
        Port = 7456;
        User = "djpro";
      };

      proxy = {
        HostName = "proxy-jia-opena0.tailc7b8fd.ts.net";
        Port = 7456;
        User = "opena0";
      };
    };
  };
}
