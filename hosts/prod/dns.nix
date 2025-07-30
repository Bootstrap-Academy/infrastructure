{ pkgs, ... }:

{
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = true;
    alwaysKeepRunning = true;
    settings = {
      no-hosts = true;
      no-resolv = true;
      server = [
        "127.0.0.1#5353"
        "::1#5353"
      ];
      host-record = [
        "prod.internal.bootstrap.academy,10.23.0.2"
        "sandkasten.internal.bootstrap.academy,10.23.0.3"
        "test.internal.bootstrap.academy,10.23.0.4"
      ];
      address = [
        "/api.bootstrap.academy/"
        "/api.bootstrap.academy/10.23.0.2"
        "/glitchtip.bootstrap.academy/"
        "/glitchtip.bootstrap.academy/10.23.0.2"
        "/sandkasten.bootstrap.academy/"
        "/sandkasten.bootstrap.academy/10.23.0.2"
        "/prod.internal.bootstrap.academy/"
        "/prod.internal.bootstrap.academy/10.23.0.2"

        "/sandkasten.internal.bootstrap.academy/"
        "/sandkasten.internal.bootstrap.academy/10.23.0.3"

        "/api.test.bootstrap.academy/"
        "/api.test.bootstrap.academy/10.23.0.4"
        "/test.internal.bootstrap.academy/"
        "/test.internal.bootstrap.academy/10.23.0.4"
      ];
    };
  };

  services.unbound = {
    enable = true;
    resolveLocalQueries = false;
    enableRootTrustAnchor = true;
    settings = {
      server = {
        port = 5353;
        root-hints = "${pkgs.dns-root-data}/root.hints";
        prefetch = true;
        prefetch-key = true;
      };
      remote-control = {
        control-enable = true;
      };
    };
  };

  environment.persistence."/persistent/cache".directories = [ "/var/lib/unbound" ];

  services.resolved.enable = false;
}
