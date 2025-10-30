{
  net = {
    internal = "10.23.0.0/23";
    wg = "10.23.1.0/24";
  };

  host = {
    prod = "10.23.0.2";
    sandkasten = "10.23.0.3";
    test = "10.23.0.4";
  };

  wg = rec {
    defelo = "10.23.1.2";
    nico-p14s = "10.23.1.3";
    nico-prod = "10.23.1.4";

    admins = [
      defelo
      nico-p14s
      nico-prod
    ];
  };

  ssh-key = {
    prod = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINO51jmJDWrG6eDLk7l0bEw4154r0jnvPyqug2aAMv4M";
  };
}
