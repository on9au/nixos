{pkgs, ...}: let
  unlock = pkgs.writeShellApplication {
    name = "brave";
    runtimeInputs = with pkgs; [
      fuzzel
      gocryptfs
      libnotify
      util-linux
    ];
    runtimeEnv.BRAVE = "${pkgs.brave}/bin/brave";
    text = builtins.readFile ./brave.sh;
  };
in {
  environment.systemPackages = [
    # Brave with its launcher and desktop entries pointed at the unlock
    # wrapper, so nothing starts it without the vault being opened first.
    (pkgs.symlinkJoin {
      name = "brave-${pkgs.brave.version}";
      paths = [pkgs.brave];
      postBuild = ''
        ln -sf ${unlock}/bin/brave $out/bin/brave
        for f in $out/share/applications/*.desktop; do
          src=$(readlink -f "$f")
          rm "$f"
          sed 's|${pkgs.brave}/bin/brave|${unlock}/bin/brave|g' "$src" > "$f"
        done
      '';
    })
  ];

  homeManagerModules = [./home.nix];
}
