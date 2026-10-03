{
  config,
  lib,
  options,
  ...
}:

let
  backend = config.academy.backend;
  cfg = backend.learningAccess;
  backendAvailable = options ? services.academy.backend.enable;
  skillsAvailable = options ? academy.backend.skills.settings;
  selectedCohort = cfg.userIds != [ ] || cfg.registeredSince != null;
in
{
  options.academy.backend.learningAccess = {
    enable = lib.mkEnableOption "the shared learning-access policy API";
    policyMode = lib.mkOption {
      type = lib.types.enum [
        "legacy"
        "shadow"
        "daily"
      ];
      default = "legacy";
      description = "Backend policy. Shadow retains existing terms and heart rules.";
    };
    termsVersion = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Explicitly approved version required for daily-policy eligibility.";
    };
    acceptedSince = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "RFC3339 lower bound for the corresponding explicit acceptance.";
    };
    registrationTermsVersion = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional signup-only version; existing account acceptance stays separate.";
    };
    registeredSince = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional RFC3339 registration cohort; acceptance is still required.";
    };
    userIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Explicit pilot user UUIDs; never an implicit all-user rollout.";
    };
    dailyDocuments = lib.mkOption {
      default = null;
      description = "Approved immutable originals bound to new daily-policy offers.";
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            termsPdfPath = lib.mkOption { type = lib.types.path; };
            termsSha256 = lib.mkOption { type = lib.types.strMatching "[0-9a-f]{64}"; };
            withdrawalPdfPath = lib.mkOption { type = lib.types.path; };
            withdrawalSha256 = lib.mkOption { type = lib.types.strMatching "[0-9a-f]{64}"; };
          };
        }
      );
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion =
            (cfg.enable && cfg.registrationTermsVersion != null)
            -> (
              cfg.policyMode == "daily"
              && cfg.registrationTermsVersion == cfg.termsVersion
              && cfg.registeredSince != null
              && cfg.acceptedSince == cfg.registeredSince
            );
          message = "Registration-only daily terms require a matching daily version and a new-registration cohort with the same acceptance date.";
        }
        {
          assertion = cfg.enable -> (backend.enable && backendAvailable && skillsAvailable);
          message = "Learning access requires the backend and Skills modules.";
        }
        {
          assertion =
            (cfg.enable && cfg.policyMode == "daily")
            -> (
              cfg.termsVersion != null
              && cfg.termsVersion != ""
              && cfg.acceptedSince != null
              && cfg.acceptedSince != ""
              && selectedCohort
              && cfg.dailyDocuments != null
            );
          message = "Daily learning requires approved terms and document originals, an acceptance date and an explicit cohort.";
        }
        {
          assertion =
            (cfg.enable && cfg.dailyDocuments != null) -> (cfg.termsVersion != null && cfg.termsVersion != "");
          message = "Learning contract originals require their matching terms version.";
        }
      ];
    }
    (lib.mkIf (cfg.enable && backend.enable) (
      lib.mkMerge [
        (lib.optionalAttrs backendAvailable {
          services.academy.backend.settings.learning_policy = {
            mode = cfg.policyMode;
            user_ids = cfg.userIds;
          }
          // lib.optionalAttrs (cfg.termsVersion != null) { terms_version = cfg.termsVersion; }
          // lib.optionalAttrs (cfg.acceptedSince != null) { accepted_since = cfg.acceptedSince; }
          // lib.optionalAttrs (cfg.registeredSince != null) { registered_since = cfg.registeredSince; }
          // lib.optionalAttrs (cfg.dailyDocuments != null && cfg.termsVersion != null) {
            daily_documents = {
              terms_version = cfg.termsVersion;
              terms_pdf_path = toString cfg.dailyDocuments.termsPdfPath;
              terms_sha256 = cfg.dailyDocuments.termsSha256;
              withdrawal_pdf_path = toString cfg.dailyDocuments.withdrawalPdfPath;
              withdrawal_sha256 = cfg.dailyDocuments.withdrawalSha256;
            };
          };
        })
        (lib.optionalAttrs backendAvailable (
          lib.mkIf (cfg.registrationTermsVersion != null) {
            services.academy.backend.settings.user.registration_terms_version = cfg.registrationTermsVersion;
          }
        ))
        (lib.optionalAttrs skillsAvailable {
          academy.backend.skills.settings.DAILY_LIMIT_POLICY_ENABLED = "true";
          sops.templates."academy-backend/skills-ms".content = lib.mkAfter ''
            INTERNAL_JWT_SECRET_CHALLENGES=${config.academy.backend.internalJwtSecrets.values.challenges}
          '';
        })
      ]
    ))
  ];
}
