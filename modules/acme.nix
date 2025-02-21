{ config, lib, ... }:
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@bootstrap.academy";
  };

  environment.persistence = lib.mkIf (config.security.acme.certs != { }) {
    "/persistent/data".directories = [ "/var/lib/acme" ];
  };
}
