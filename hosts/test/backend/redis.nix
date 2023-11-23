{
  services.redis.servers."" = {
    enable = true;
    bind = null;
    save = [];
    settings.protected-mode = "no";
  };
}
