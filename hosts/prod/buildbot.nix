{
  buildbot-nix,
  config,
  lib,
  pkgs,
  ...
}: let
  domain = "buildbot.bootstrap.academy";
  port = 8006;
  cache = "/persistent/cache/buildbot";
  gcroots = "${cache}/gcroots";
in {
  disabledModules = [
    "services/continuous-integration/buildbot/master.nix"
    "services/continuous-integration/buildbot/worker.nix"
  ];

  imports = [
    "${buildbot-nix.inputs.nixpkgs}/nixos/modules/services/continuous-integration/buildbot/master.nix"
    "${buildbot-nix.inputs.nixpkgs}/nixos/modules/services/continuous-integration/buildbot/worker.nix"
    buildbot-nix.nixosModules.buildbot-master
    buildbot-nix.nixosModules.buildbot-worker
  ];

  services.buildbot-nix.master = {
    inherit domain;
    enable = true;
    useHTTPS = true;
    workersFile = config.sops.templates."buildbot/workersFile".path;
    outputsPath = "${cache}/outputs/";
    evalWorkerCount = 1;
    admins = ["Defelo"];
    github = {
      authType.app = {
        id = 1040284;
        secretKeyFile = config.sops.secrets."buildbot/github_private_key".path;
      };
      oauthId = "Iv23lis55RKX1EfHBCeu";
      oauthSecretFile = config.sops.secrets."buildbot/oauth_secret".path;
      webhookSecretFile = config.sops.secrets."buildbot/webhook_secret".path;
      topic = "build-with-buildbot";
    };
    postBuildSteps = [
      {
        name = "Add gcroot";
        command = let
          prop = name: buildbot-nix.lib.interpolate "%(prop:${name})s";
          script = pkgs.writeShellScript "buildbot-add-gcroot.sh" ''
            readonly project="$1" attr="$2" out_path="$3"
            readonly dir="${gcroots}/$project/$attr"
            readonly profile="$dir/result"
            mkdir -p "$dir"
            nix-env --set --profile "$profile" "$out_path"
            nix-env --delete-generations --profile "$profile" old
          '';
        in ["${script}" (prop "project") (prop "attr") (prop "out_path")];
      }
    ];
  };

  services.buildbot-master.port = port;

  services.buildbot-nix.worker = {
    enable = true;
    workerPasswordFile = config.sops.secrets."buildbot/worker_password".path;
  };

  systemd.services.buildbot-worker.serviceConfig.ExecStartPre = [
    "+${lib.getExe' pkgs.coreutils "mkdir"} -p ${gcroots}"
    "+${lib.getExe' pkgs.coreutils "chown"} -R buildbot-worker:buildbot-worker ${gcroots}"
    "+${lib.getExe' pkgs.acl "setfacl"} -dR -m u:buildbot:rwx,u:buildbot-worker:rwx ${gcroots}"
    "+${lib.getExe' pkgs.acl "setfacl"} -R -m u:buildbot:rwx,u:buildbot-worker:rwx ${gcroots}"
  ];

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    enableACME = true;
    # extraConfig = ''
    #   allow 10.23.1.0/24;
    #   deny all;
    # '';
    # locations."/change_hook/github" = {
    #   proxyPass = "http://127.0.0.1:${toString port}/change_hook/github";
    #   extraConfig = ''
    #     allow all;
    #   '';
    # };
  };

  environment.persistence."/persistent/cache".directories = [
    "/var/lib/buildbot"
    "/var/lib/buildbot-worker"
  ];

  sops = {
    secrets = {
      "buildbot/github_private_key" = {};
      "buildbot/webhook_secret" = {};
      "buildbot/worker_password" = {};
      "buildbot/oauth_secret" = {};
    };
    templates."buildbot/workersFile".content = builtins.toJSON [
      {
        name = "prod";
        pass = config.sops.placeholder."buildbot/worker_password";
        cores = 4;
      }
    ];
  };
}
