# Each server's mods and game version are its packwiz pack in servers/<name>.
# The proxy's haproxy.nix reads the ports from here too.
{
  smp = {
    port = 25565;
    # GiB of heap.
    memory = 4;
    # Only players.nix may join.
    whitelist = true;
    properties = {
      difficulty = "normal";
      motd = "smp";
    };
  };
}
