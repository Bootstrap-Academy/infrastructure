{
  config,
  lib,
  pkgs,
  shop-ms-develop,
  ...
}:
lib.mkIf config.academy.backend.enable {
  environment.shellAliases.generate-invoices = "sudo -u academy-shop env DATABASE_URL=${config.academy.backend.shop.settings.DATABASE_URL} AUTH_URL=${config.academy.backend.common.environment.AUTH_URL} $(head -1 ${config.sops.templates."academy-backend/common".path}) ${shop-ms-develop.packages.${pkgs.system}.default}/bin/generate_invoices";
}
