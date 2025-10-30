{ env, pkgs, ... }:

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
        "prod.internal.bootstrap.academy,${env.host.prod}"
        "sandkasten.internal.bootstrap.academy,${env.host.sandkasten}"
        "test.internal.bootstrap.academy,${env.host.test}"
      ];
      address = [
        "/api.bootstrap.academy/"
        "/api.bootstrap.academy/${env.host.prod}"
        "/glitchtip.bootstrap.academy/"
        "/glitchtip.bootstrap.academy/${env.host.prod}"
        "/sandkasten.bootstrap.academy/"
        "/sandkasten.bootstrap.academy/${env.host.prod}"
        "/prod.internal.bootstrap.academy/"
        "/prod.internal.bootstrap.academy/${env.host.prod}"

        "/sandkasten.internal.bootstrap.academy/"
        "/sandkasten.internal.bootstrap.academy/${env.host.sandkasten}"

        "/api.test.bootstrap.academy/"
        "/api.test.bootstrap.academy/${env.host.test}"
        "/test.internal.bootstrap.academy/"
        "/test.internal.bootstrap.academy/${env.host.test}"
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
