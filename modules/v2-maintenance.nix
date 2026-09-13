{ config, lib, ... }:

{
  config =
    lib.mkIf
      (
        config.academy.backend.enable
        && builtins.elem config.networking.hostName [
          "test"
          "prod"
        ]
      )
      {
        services.nginx = {
          appendHttpConfig = ''
            # Check the original socket peer, never a forwarded client-IP header.
            # SSH forwards to the canonical HTTPS listener from loopback.
            map $realip_remote_addr $academy_v2_loopback {
              default 0;
              127.0.0.1 1;
              ::1 1;
            }
            map "$academy_v2_maintenance:$academy_v2_loopback" $academy_v2_unavailable {
              default 0;
              "1:0" 1;
            }
          '';

          # Run before the existing server-level OPTIONS response and all locations.
          # Normal operation only changes when root creates this runtime marker.
          # Recovery remains publicly closed even after a reboot removes /run files.
          virtualHosts.${config.academy.backend.domain}.extraConfig = lib.mkBefore ''
            set $academy_v2_maintenance ${if config.academy.v2Recovery then "1" else "0"};
            if (-f /run/academy-v2-maintenance) {
              set $academy_v2_maintenance 1;
            }
            if ($academy_v2_unavailable) {
              return 503;
            }
          '';
        };
      };
}
