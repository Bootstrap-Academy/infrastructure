{sandkasten, ...}: let
  port = 8000;
in {
  imports = [sandkasten.nixosModules.sandkasten];

  services.sandkasten = {
    enable = true;

    environments = p: with p; [all];

    settings = {
      inherit port;
      host = "0.0.0.0";
    };
  };

  networking.firewall.allowedTCPPorts = [port];
}
