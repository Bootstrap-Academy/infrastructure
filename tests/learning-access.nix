{ source }:

let
  flake = builtins.getFlake source;
  lib = flake.inputs.nixpkgs.lib;
  dailyConfig = {
    enable = true;
    policyMode = "daily";
    termsVersion = "review-fixture";
    acceptedSince = "2026-09-26T00:00:00Z";
    userIds = [ "00000000-0000-4000-8000-000000000001" ];
    dailyDocuments = {
      termsPdfPath = "/run/learning-access-test/terms.pdf";
      termsSha256 = lib.concatStrings (lib.replicate 64 "a");
      withdrawalPdfPath = "/run/learning-access-test/withdrawal.pdf";
      withdrawalSha256 = lib.concatStrings (lib.replicate 64 "b");
    };
  };
  describe =
    host: extra:
    let
      cfg = (flake.nixosConfigurations.${host}.extendModules { modules = [ extra ]; }).config;
    in
    {
      failures = map (item: item.message) (builtins.filter (item: !item.assertion) cfg.assertions);
      backendPolicy = cfg.services.academy.backend.settings.learning_policy or null;
      skillsPolicy = cfg.academy.backend.skills.settings.DAILY_LIMIT_POLICY_ENABLED or null;
      registrationVersion = cfg.services.academy.backend.settings.user.registration_terms_version or null;
      historySecretConfigured =
        lib.hasInfix "INTERNAL_JWT_SECRET_CHALLENGES="
          cfg.sops.templates."academy-backend/skills-ms".content;
    };
in
{
  disabled = lib.genAttrs [ "test" "prod" "sandkasten" ] (host: {
    enabled = flake.nixosConfigurations.${host}.config.academy.backend.learningAccess.enable;
    systemDrv = flake.nixosConfigurations.${host}.config.system.build.toplevel.drvPath;
  });
  shadow = lib.genAttrs [ "test" "prod" ] (
    host:
    describe host {
      academy.backend.learningAccess = {
        enable = true;
        policyMode = "shadow";
      };
    }
  );
  daily = describe "test" { academy.backend.learningAccess = dailyConfig; };
  newRegistrations = describe "test" {
    academy.backend.learningAccess = dailyConfig // {
      registrationTermsVersion = "review-fixture";
      registeredSince = "2026-09-26T00:00:00Z";
    };
  };
  mismatchedRegistration = describe "test" {
    academy.backend.learningAccess = dailyConfig // {
      registrationTermsVersion = "wrong-fixture";
      registeredSince = "2026-09-26T00:00:00Z";
    };
  };
  mismatchedRegistrationDate = describe "test" {
    academy.backend.learningAccess = dailyConfig // {
      registrationTermsVersion = "review-fixture";
      registeredSince = "2026-10-26T00:00:00Z";
    };
  };
  missingConsent = describe "test" {
    academy.backend.learningAccess = dailyConfig // {
      acceptedSince = null;
    };
  };
  missingCohort = describe "test" {
    academy.backend.learningAccess = dailyConfig // {
      userIds = [ ];
    };
  };
  missingDocuments = describe "test" {
    academy.backend.learningAccess = dailyConfig // {
      dailyDocuments = null;
    };
  };
  documentsWithoutVersion = describe "test" {
    academy.backend.learningAccess = dailyConfig // {
      policyMode = "shadow";
      termsVersion = null;
    };
  };
}
