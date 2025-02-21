{
  pkgs,
  config,
  lib,
  ...
}:
{
  config =
    let
      cfg = config.academy.backend;
      new = config.services.academy.backend.enable or false;
    in
    lib.mkIf cfg.enable {
      services.nginx = {
        enable = true;

        appendHttpConfig = ''
          map $http_origin $allow_origin {
            ${builtins.concatStringsSep "\n  " (map (origin: "~${origin} $http_origin;") cfg.corsOrigins)}
            default "";
          }
        '';

        virtualHosts.${cfg.domain} = {
          forceSSL = true;
          enableACME = true;
          extraConfig = ''
            more_set_headers "Access-Control-Allow-Origin: $allow_origin";
            more_set_headers "Access-Control-Allow-Headers: *, Authorization";
            more_set_headers "Access-Control-Allow-Methods: *";

            if ($request_method = 'OPTIONS') {
              return 200;
            }
          '';
          locations =
            lib.mapAttrs' (
              ms:
              { port, ... }:
              {
                name = "/${ms}/";
                value = {
                  proxyPass = "http://127.0.0.1:${toString port}/";
                  proxyWebsockets = true;
                };
              }
            ) cfg.microservices
            // (lib.mapAttrs' (
              ms:
              { port, ... }:
              {
                name = "= /${ms}/";
                value = {
                  return = "307 /${ms}/docs";
                };
              }
            ) cfg.microservices)
            // (lib.optionalAttrs (cfg.protectInternalEndpoints) { "~* (:*/_internal/.*)".return = "403"; })
            // {
              "= /" = {
                tryFiles = "/index.html =404";
                root = pkgs.writeTextDir "index.html" ''
                  <html>
                    <head>
                      <title>${cfg.name}</title>
                      <style>
                        body {
                          padding: 8px;
                        }
                        table, td, th {
                          border: 1px solid;
                          border-collapse: collapse;
                          padding: 6px;
                        }
                      </style>
                    </head>
                    <body>
                      <h1>${cfg.name}</h1>
                      <table>
                        <tr>
                          <th>Component</th>
                          <th>Base URL</th>
                          <th>Documentation</th>
                          <th>Repository</th>
                        </tr>
                        ${lib.optionalString new ''
                          <tr>
                            <td>backend</td>
                            <td><a href="/">https://${cfg.domain}/</a></td>
                            <td>
                              <a href="/docs">Swagger</a>
                              <a href="/redoc">Redoc</a>
                              <a href="/openapi.json">OpenAPI</a>
                            </td>
                            <td>
                              <a href="https://github.com/Bootstrap-Academy/backend">https://github.com/Bootstrap-Academy/backend</a>
                            </td>
                          </tr>
                        ''}
                  ${builtins.concatStringsSep "\n" (
                    map
                      (ms: ''
                        <tr>
                          <td>${ms}-ms</td>
                          <td><a href="${ms}">https://${cfg.domain}/${ms}</a></td>
                          <td>
                            <a href="${ms}/docs">Swagger</a>
                            <a href="${ms}/redoc">Redoc</a>
                            <a href="${ms}/openapi.json">OpenAPI</a>
                          </td>
                          <td>
                            <a href="https://github.com/Bootstrap-Academy/${ms}-ms">https://github.com/Bootstrap-Academy/${ms}-ms</a>
                          </td>
                        </tr>
                      '')
                      (
                        builtins.sort (a: b: cfg.microservices.${a}.port < cfg.microservices.${b}.port) (
                          builtins.attrNames cfg.microservices
                        )
                      )
                  )}
                      </table>
                    </body>
                  </html>
                '';
              };
            };
        };
      };
    };
}
