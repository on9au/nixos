# Headless counterpart to network.nix, which uses NetworkManager: there is no
# user session here to hand link management to.
{...}: {
  networking.useNetworkd = true;
  networking.useDHCP = false;

  # Any wired link takes a lease. A host needing a static address defines its
  # own lower-numbered systemd.network.networks entry.
  systemd.network.networks."40-wired" = {
    matchConfig.Type = "ether";
    networkConfig.DHCP = "yes";
    linkConfig.RequiredForOnline = "routable";
  };

  # networkd delegates DNS to resolved; without it nothing writes resolv.conf.
  services.resolved.enable = true;
}
