{
  config,
  lib,
  ...
}: {
  config = let
    cfg = config.academy.backend;
  in
    lib.mkIf cfg.enable {
      services.redis.servers."" = {
        enable = true;
        bind = null;
        save = [];
        settings.protected-mode = "no";
      };
    };
}
