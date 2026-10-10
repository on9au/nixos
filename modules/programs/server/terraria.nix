{...}: {
  virtualisation.oci-containers.containers.terraria = {
    image = "ryshe/terraria:vanilla-1.4.5.8";
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

  # The server is root with no capabilities, so it can only write what root
  # owns. Reapplied each boot and switch: a restore brings back uid 1000.
  systemd.tmpfiles.settings."10-homelab" = {
    "/var/lib/homelab/terraria/config".Z = {
      group = "root";
      user = "root";
    };
    "/var/lib/homelab/terraria/worlds".Z = {
      group = "root";
      user = "root";
    };
  };
}
