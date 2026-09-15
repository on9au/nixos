{...}: {
  virtualisation.oci-containers.containers.terraria = {
    image = "ryshe/terraria:latest";
    environment = {
      CONFIGPATH = "/config";
      CONFIG_FILENAME = "serverconfig.txt";
      WORLD_FILENAME = "retards.wld";
    };
    ports = ["7777:7777"];
    volumes = [
      "/var/lib/homelab/terraria/config:/config"
      "/var/lib/homelab/terraria/worlds:/root/.local/share/Terraria/Worlds"
    ];
    # tshock's console wants a tty. Compose's stdin_open has no equivalent here:
    # adding -i makes docker demand a terminal from systemd, which has none.
    extraOptions = ["--tty"];
  };
}
