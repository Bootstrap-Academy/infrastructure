{ lib, ... }: {
  imports = [ ../sandkasten/sandkasten.nix ];

  academy.sandboxHardening.enable = true;
  services.sandkasten.settings = {
    host = lib.mkForce "127.0.0.1";
    port = lib.mkForce 18080;
  };

  # Learning workers keep their existing executor until technical-error
  # classification is merged and verified. This instance is isolated on Test.
}
