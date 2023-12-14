{
  net.internal = {
    net4 = "10.23.0.0/23";
    servers.net4 = "10.23.0.0/24";
    wireguard.net4 = "10.23.1.0/24";
  };

  servers = {
    prod = {
      system = "aarch64-linux";

      net = {
        public.ip4 = "157.90.144.125";
        public.ip6 = "2a01:4f8:c012:a47b::";
        private.ip4 = "10.23.0.2";
        wireguard.ip4 = "10.23.1.1";
      };

      dev = {
        public = "enp1s0";
        private = "enp7s0";
        wireguard = "wg0";
      };

      wireguard = {
        port = 51820;
        peers = {
          defelo = {
            publicKey = "1g/V66LITNSzZD0DDIKt4l3u8/yOGYEOtcArAXMvHyQ=";
            ip4 = "10.23.1.2";
          };
          nico-t480 = {
            publicKey = "EtC01X70ExI7Kvrp5tzE8wWlcbKD/QHg6wIvUB5ewQI=";
            ip4 = "10.23.1.3";
          };
          nico-ws1 = {
            publicKey = "PrSCG2vuAiHKnB3AJm1ii6T2LHaB8ZRu8GinjPGfXEc=";
            ip4 = "10.23.1.4";
          };
          nico-hm90 = {
            publicKey = "aMKMkLo92dHyvbB3vDde4kF9DQLGnw0NqocLGK4KcBA=";
            ip4 = "10.23.1.5";
          };
        };
      };

      ssh.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDICX5+RkzRMCwFqAbGrWOTPTsz53/7byvp6GGcvKQbV";
    };

    sandkasten = {
      system = "aarch64-linux";

      net.private.ip4 = "10.23.0.3";

      dev.private = "enp7s0";

      ssh.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN0OY+9GYyDhQvaS1jCLKU7J6FA6BnsYmrFbmBguqYPE";
    };

    test = {
      system = "aarch64-linux";

      net = {
        public.ip4 = "49.13.80.22";
        public.ip6 = "2a01:4f8:c17:ad51::";
        private.ip4 = "10.23.0.4";
      };

      dev = {
        public = "enp1s0";
        private = "enp7s0";
      };

      ssh.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPqxUuWXNok1tN0epFzfsfRm7bcPs5G/ixzigCZRKLLb";
    };
  };

  sshKeys = {
    defelo = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID0+Dd5FL6zKIxkjJaOb+/7fp5YtePkDdGasYESAl0br"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCqDljgWk+qK1pHdTZdgFgXcMdizAz7OmGR9fx0yROQ6+Ja7zUxnAxOi0ijOk8HLWrZ9xu/TqKPvF29hndCEJtg="
    ];
    nico = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE2k27mRS2MmZ+b0QqF7eGonD8pEQE3lqFTLUHkUDK3X"
    ];
  };

  sshHostKeys = {
    "u381435.your-storagebox.de" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
  };
}
