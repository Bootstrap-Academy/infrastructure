{ config, lib, ... }:

let
  # Server logs are deleted after 30 days, as stated in the privacy notice.
  retentionDays = 30;
in

{
  services.journald.extraConfig = ''
    MaxRetentionSec=${toString retentionDays}day
    SystemMaxUse=1G
  '';

  # nginx writes its error log to stderr and therefore to the journal; only the
  # access logs are rotated by logrotate.
  services.logrotate.settings = lib.mkIf config.services.nginx.enable {
    nginx = {
      frequency = "daily";
      rotate = retentionDays;
      maxage = retentionDays;
    };
  };
}
