{ lib, ... }: {
  imports = [ ../sandkasten/sandkasten.nix ];

  academy.sandboxHardening.enable = true;
  services.sandkasten.settings = {
    host = lib.mkForce "127.0.0.1";
    port = lib.mkForce 18080;
  };

  # Isolated on Test: loopback only, with the bounded program cache. Test's
  # learning workers and inline tests use it (backend/challenges.nix).
}
