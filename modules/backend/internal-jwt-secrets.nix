{ config, lib, ... }:

let
  cfg = config.academy.backend.internalJwtSecrets;

  secretName = audience: "academy-backend/internal-jwt-secret/${audience}";
in

{
  options.academy.backend.internalJwtSecrets = {
    enable = lib.mkEnableOption ''
      per audience secrets for the internal service tokens.

      The monolith and the microservices then sign a service token with the
      secret of the audience it is addressed to, and verify an incoming one
      with the secret of their own audience, instead of using the shared
      `academy-backend/jwt-secret` for everything. A key taken from one service
      can therefore no longer be used to talk to another one.

      Every service only receives the secrets of the audiences it actually
      talks to plus its own.

      Requires one secret per audience in the host's `secrets.yml`, activation
      fails without them:

      ```yaml
      academy-backend:
          internal-jwt-secret:
              auth: <64 random bytes, base64>
              shop: <64 random bytes, base64>
              skills: <64 random bytes, base64>
              challenges: <64 random bytes, base64>
              events: <64 random bytes, base64>
              jobs: <64 random bytes, base64>
      ```

      While this is off every audience is handed an empty value, which the
      services read as "fall back to the shared jwt secret". That is the
      behaviour of the deployment as it stands today
    '';

    audiences = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "auth"
        "shop"
        "skills"
        "challenges"
        "events"
        "jobs"
      ];
      readOnly = true;
      description = "The audiences an internal service token can be issued for.";
    };

    values = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = lib.genAttrs cfg.audiences (
        audience: lib.optionalString cfg.enable config.sops.placeholder.${secretName audience}
      );
      defaultText = lib.literalMD ''
        the sops placeholder of each audience's secret, or an empty string while
        this is disabled
      '';
      description = ''
        The value to interpolate into a secret template, per audience. Only the
        audiences a service talks to belong into its template.
      '';
    };
  };

  config.sops.secrets = lib.mkIf cfg.enable (lib.genAttrs (map secretName cfg.audiences) (_: { }));
}
