{ ... }:
{
  # Capture test notifications locally, including recovery after a deployment.
  # Neither SMTP nor the mailbox UI is exposed outside this host.
  services.mailpit.instances.academy-test = {
    smtp = "127.0.0.1:1025";
    listen = "127.0.0.1:8025";
    max = 200;
    smtp-auth-accept-any = true;
    smtp-auth-allow-insecure = true;
  };

  systemd.services.mailpit-academy-test.serviceConfig = {
    UMask = "0077";
    StateDirectoryMode = "0700";
    PrivateTmp = true;
  };

  systemd.services.academy-backend = {
    after = [ "mailpit-academy-test.service" ];
    requires = [ "mailpit-academy-test.service" ];
  };
}
