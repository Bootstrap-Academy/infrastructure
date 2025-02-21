{ config, lib, ... }:
{
  options.monitoring = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    nginxLogFormat = lib.mkOption {
      type = lib.types.str;
      default = ''ra="$remote_addr" ru="$remote_user" [$time_local] h="$host" r="$request" s="$status" bbs="$body_bytes_sent" hr="$http_referer" hua="$http_user_agent" rt="$request_time" uct="$upstream_connect_time" uht="$upstream_header_time" urt="$upstream_response_time"'';
    };
  };

  config =
    let
      cfg = config.monitoring;
    in
    lib.mkIf cfg.enable {
      services.prometheus.exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
          port = 9000;
        };

        nginx = lib.mkIf config.services.nginx.enable {
          enable = true;
          port = 9001;
        };

        nginxlog = lib.mkIf config.services.nginx.enable {
          enable = true;
          port = 9002;
          group = "nginx";
          settings = {
            namespaces = [
              {
                name = "nginx";
                format = cfg.nginxLogFormat;
                source.files = [ "/var/log/nginx/prometheus.log" ];
                relabel_configs = [
                  {
                    target_label = "host";
                    from = "host";
                  }
                ];
              }
            ];
          };
        };
      };
    };
}
