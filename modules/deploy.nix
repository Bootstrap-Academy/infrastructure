{
  config,
  deploy-sh,
  lib,
  ...
}:
{
  imports = [ deploy-sh.nixosModules.default ];

  deploy-sh.targetHost =
    let
      ip = config.networking.networks.private.internal.ip4 or null;
    in
    lib.mkIf (ip != null) (lib.mkDefault "root@${ip}");
}
