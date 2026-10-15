# An isolated sandbox on Test for the lesson engine's runner (docs/sandbox-hardening.md).
# It runs the pinned Sandkasten with the hardening module on loopback, with the run limits
# of the shared sandbox in ../sandkasten/sandkasten.nix, so a measurement here applies there.
# Nothing calls it yet: the coding workers of Test keep the shared sandbox at 10.23.0.3:8000.
{ lib, ... }:

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
      host = lib.mkForce "127.0.0.1";
      port = lib.mkForce 18080;
      # One job at a time keeps a measurement undisturbed and leaves Test's second CPU to its services.
      max_concurrent_jobs = lib.mkForce 1;
      base_resource_usage.permits = lib.mkForce 1;
    };
  };

  # One job (512 MB) plus the cache (128 MiB) and the supervisor; the module's 4 GiB exceeds Test's memory.
  systemd.services.sandkasten.serviceConfig.MemoryMax = lib.mkForce "1G";
}
