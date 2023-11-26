{
  pkgs,
  config,
  lib,
  ...
}: {
  config = let
    cfg = config.academy.backend;
  in
    lib.mkIf cfg.enable {
      services.nginx = {
        enable = true;

        virtualHosts.${cfg.domain} = {
          forceSSL = true;
          enableACME = true;
          locations =
            lib.mapAttrs' (ms: {port, ...}: {
              name = "/${ms}/";
              value = {
                proxyPass = "http://127.0.0.1:${toString port}/";
                proxyWebsockets = true;
              };
            })
            cfg.microservices
            // (
              lib.mapAttrs' (ms: {port, ...}: {
                name = "= /${ms}/";
                value = {
                  return = "307 /${ms}/docs";
                };
              })
              cfg.microservices
            )
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
                          <th>Microservice</th>
                          <th>Base URL</th>
                          <th>Documentation</th>
                        </tr>
                        ${builtins.concatStringsSep "\n" (map (ms: ''
                    <tr>
                      <td>${ms}</td>
                      <td><a href="auth">https://${cfg.domain}/${ms}</a></td>
                      <td>
                        <a href="${ms}/docs">Swagger</a>
                        <a href="${ms}/redoc">Redoc</a>
                        <a href="${ms}/openapi.json">OpenAPI</a>
                      </td>
                    </tr>
                  '') (builtins.attrNames cfg.microservices))}
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
