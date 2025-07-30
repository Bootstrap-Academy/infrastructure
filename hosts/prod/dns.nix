{
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = true;
    alwaysKeepRunning = true;
    settings = {
      no-hosts = true;
      no-resolv = true;
      server = [
        "1.1.1.1"
        "1.0.0.1"
        "2606:4700:4700::1111"
        "2606:4700:4700::1001"
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

  services.resolved.enable = false;
}
