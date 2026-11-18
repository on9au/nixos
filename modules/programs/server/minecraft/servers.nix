# Each server's mods and game version are its packwiz pack in servers/<name>.
# The proxy's haproxy.nix reads the ports from here too.
{
  city = {
    port = 25566;
    memory = 4;
    whitelist = true;
    # Everyone in players.nix is op: Axiom and WorldEdit need it.
    op = true;
    # Gamerules are in servers/city/datapack.
    properties = {
      difficulty = "peaceful";
      force-gamemode = true;
      gamemode = "creative";
      generate-structures = false;
      motd = "city";
    };
  };

  smp = {
    port = 25565;
    # GiB of heap.
    memory = 4;
    # Only players.nix may join.
    whitelist = true;
    op = false;
    properties = {
      difficulty = "normal";
      motd = "smp";
    };
  };
}
