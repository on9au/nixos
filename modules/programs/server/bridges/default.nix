{lib, ...}: let
  # Images must match scaffold.sh, which writes each bridge's config.
  # mediaPort is the appservice port, which also serves direct media.
  bridges = {
    discord = {
      image = "dock.mau.dev/mautrix/discord:v0.7.7";
      mediaPort = 29334;
    };
    # RCS media has no HTTP URL to hand out, so no direct media and no subdomain.
    gmessages = {
      image = "dock.mau.dev/mautrix/gmessages:v26.09";
      mediaPort = null;
    };
    instagram = {
      image = "dock.mau.dev/mautrix/meta:ig-v26.09";
      mediaPort = 29322;
    };
    messenger = {
      image = "dock.mau.dev/mautrix/meta:v26.09";
      mediaPort = 29321;
    };
    telegram = {
      image = "dock.mau.dev/mautrix/telegram:v26.09";
      mediaPort = 29317;
    };
    whatsapp = {
      image = "dock.mau.dev/mautrix/whatsapp:v26.09";
      mediaPort = 29318;
    };
  };
in {
  virtualisation.oci-containers.containers = lib.mapAttrs' (name: bridge:
    lib.nameValuePair "mautrix-${name}" {
      image = bridge.image;
      volumes = ["/var/lib/homelab/bridges/${name}/data:/data"];
      networks = ["proxy"];
      # docker-run.sh chowns /data, then drops to the bridge's user.
      capabilities = {
        CHOWN = true;
        DAC_OVERRIDE = true;
        FOWNER = true;
        SETGID = true;
        SETUID = true;
      };
      # Direct media: the bridge mints signed mxc:// URIs on its own server name
      # and serves the bytes itself, so the whole subdomain has to reach it --
      # federation media, client media, /_matrix/key and .well-known.
      labels = lib.optionalAttrs (bridge.mediaPort != null) {
        caddy = "${name}-media.opena0.net";
        "caddy.reverse_proxy" = "{{upstreams ${toString bridge.mediaPort}}}";
      };
    })
  bridges;
}
