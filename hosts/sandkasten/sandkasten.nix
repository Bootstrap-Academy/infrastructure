{sandkasten, ...}: {
  imports = [sandkasten.nixosModules.sandkasten];

  services.sandkasten = {
    enable = true;

    environments = p: with p; [all];

    settings = {
      host = "0.0.0.0";
      port = 8000;
    };
  };
}
