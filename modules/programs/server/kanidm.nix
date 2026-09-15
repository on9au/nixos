{...}: {
  # A container, not services.kanidm: nixpkgs stops at 1.9, and kanidm refuses to
  # start on a database written by a newer version.
  virtualisation.oci-containers.containers.kanidm = {
    image = "kanidm/server:1.11.0";
    user = "1000:1000";
    volumes = [
      "kanidm_certs:/certs:ro"
      "kanidm_data:/data"
    ];
    networks = ["proxy"];
    labels = {
      caddy = "idm.opena0.net";
      "caddy.reverse_proxy" = "{{upstreams https 8443}}";
      "caddy.reverse_proxy.transport" = "http";
      "caddy.reverse_proxy.transport.tls" = "";
      "caddy.reverse_proxy.transport.tls_insecure_skip_verify" = "";
    };
  };
}
