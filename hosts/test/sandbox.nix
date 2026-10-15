# An isolated sandbox on Test for the lesson engine's runner (docs/sandbox-hardening.md).
# It runs the pinned Sandkasten with the hardening module on loopback, with the run limits
# of the shared sandbox in ../sandkasten/sandkasten.nix; a time measured here is a lower bound there.
# Nothing calls it yet: the coding workers of Test keep the shared sandbox at 10.23.0.3:8000.
{ config, lib, ... }:

let
  port = 18080;
  # Test keeps its data there, readable by local accounts; the supervisor needs none of it.
  hidden = [
    "/persistent"
    "/var/lib/academy"
  ];
in
{
  imports = [ ../sandkasten/sandkasten.nix ];

  academy.sandboxHardening = {
    enable = true;
    # Room for about 900 runner programs within the five minute TTL; Test has 3.8 GiB of memory.
    cacheMiB = 128;
  };

  services.sandkasten = {
    # The runner needs Node only. This is the same javascript environment the shared sandbox offers.
    environments = lib.mkForce (packages: packages.none.withJavascript);

    settings = {
      # Inside its own network namespace; sandkasten-proxy carries the API there.
      host = lib.mkForce "127.0.0.1";
      port = lib.mkForce port;
      # One job at a time keeps a measurement undisturbed and leaves Test's second CPU to its services.
      max_concurrent_jobs = lib.mkForce 1;
      base_resource_usage.permits = lib.mkForce 1;
    };
  };

  # The supervisor runs on an application host: it reaches neither Redis nor any other service of Test.
  systemd.services.sandkasten.serviceConfig = {
    # One job (512 MB) plus the cache (128 MiB) and the supervisor; the module's 4 GiB exceeds Test's memory.
    MemoryMax = lib.mkForce "1G";
    PrivateNetwork = true;
    InaccessiblePaths = hidden;
  };

  systemd.sockets.sandkasten-proxy = {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:${toString port}" ];
  };

  systemd.services.sandkasten-proxy = {
    requires = [ "sandkasten.service" ];
    after = [ "sandkasten.service" ];
    unitConfig.JoinsNamespaceOf = "sandkasten.service";
    serviceConfig = {
      ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd 127.0.0.1:${toString port}";
      PrivateNetwork = true;
      User = "academy-sandbox";
      Group = "academy-sandbox";
      CapabilityBoundingSet = "";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      InaccessiblePaths = hidden;
    };
  };
}
