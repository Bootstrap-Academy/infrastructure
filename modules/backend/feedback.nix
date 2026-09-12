{ config, lib, ... }:

let
  cfg = config.academy.backend;
in
{
  options.academy.backend.feedback.enable = lib.mkEnableOption "public GitHub feedback";

  config = lib.mkIf (cfg.enable && cfg.feedback.enable) {
    services.academy.backend.settings.feedback = {
      enabled = true;
      github_token_file = config.sops.secrets."academy-backend/feedback-github-token".path;
      # academy-backend's StateDirectory owns this writable directory. Both
      # application hosts already persist /var/lib/academy across reboots.
      storage_path = "/var/lib/academy/feedback";
      public_base_url = "https://${cfg.domain}";
    };

    sops.secrets."academy-backend/feedback-github-token" = {
      path = "/run/secrets/feedback-github-token";
      owner = "academy";
      group = "academy";
      mode = "0400";
      restartUnits = [ "academy-backend.service" ];
    };

    # Keep the larger screenshot envelope scoped to this endpoint. Image
    # decoding, pixel limits and the JSON limit are also enforced by the API.
    services.nginx.virtualHosts.${cfg.domain}.locations."= /feedback" = {
      proxyPass = "http://127.0.0.1:8000";
      extraConfig = "client_max_body_size 5m;";
    };
  };
}
