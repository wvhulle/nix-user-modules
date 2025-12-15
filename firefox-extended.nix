{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.firefox-extended;

  developerSearchEngines = [
    {
      Name = "NixOS Packages";
      URLTemplate = "https://search.nixos.org/packages?channel=unstable&query={searchTerms}";
      Method = "GET";
      IconURL = "https://nixos.org/favicon.png";
      Alias = "@nix";
      Description = "Search NixOS packages";
    }
    {
      Name = "Home Manager Options";
      URLTemplate = "https://home-manager-options.extranix.com/?query={searchTerms}";
      Method = "GET";
      IconURL = "https://nixos.org/favicon.png";
      Alias = "@hm";
      Description = "Search Home Manager options";
    }
  ];

  mkExtension = name: id: {
    name = id;
    value = {
      installation_mode = "force_installed";
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/${name}/latest.xpi";
    };
  };

  defaultExtensions = [
    {
      name = "youtube-nonstop";
      id = "{0d7cafdd-501c-49ca-8ebb-e3341caaa55e}";
    }
    {
      name = "ublock-origin";
      id = "uBlock0@raymondhill.net";
    }
  ];

  defaultPrivacyPrefs = {
    "browser.contentblocking.category" = {
      Value = "strict";
      Status = "locked";
    };
    "privacy.trackingprotection.enabled" = true;
    "privacy.trackingprotection.socialtracking.enabled" = true;
    "privacy.trackingprotection.cryptomining.enabled" = true;
    "privacy.trackingprotection.fingerprinting.enabled" = true;
    "security.tls.version.min" = 3;
    "security.ssl.require_safe_negotiation" = true;
  };

  defaultUxPrefs = {
    "extensions.pocket.enabled" = false;
    "browser.newtabpage.activity-stream.feeds.topsites" = false;
    "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
    "browser.formfill.enable" = false;
    "browser.urlbar.suggest.searches" = false;
    "browser.tabs.warnOnClose" = false;
    "browser.tabs.warnOnCloseOtherTabs" = false;
    "browser.sessionstore.resume_from_crash" = true;
    "browser.startup.page" = 3;
    "signon.rememberSignons" = true;
    "browser.startup.homepage" = "about:blank";
    "browser.newtabpage.enabled" = false;
    "browser.tabs.loadInBackground" = true;
    "browser.tabs.insertAfterCurrent" = true;
    "devtools.theme" = "dark";
    "devtools.toolbox.host" = "bottom";
    "signon.generation.enabled" = false;
    "signon.management.page.breach-alerts.enabled" = false;
  };
in
{
  options.programs.firefox-extended = {
    enable = lib.mkEnableOption "extended firefox configuration";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.firefox;
      defaultText = lib.literalExpression "pkgs.firefox";
      description = "Firefox package to use";
    };

    additionalPreferences = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Additional Firefox preferences";
    };

    additionalPolicies = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Additional Firefox policies";
    };

    profileName = lib.mkOption {
      type = lib.types.str;
      default = "default";
      description = "Name of the Firefox profile";
    };

    bookmarks = lib.mkOption {
      type = lib.types.anything;
      default = null;
      description = "Firefox bookmarks configuration (raw bookmark structure)";
      example = lib.literalExpression ''
        [
          {
            name = "Wikipedia";
            url = "https://wikipedia.org";
          }
          {
            name = "Development";
            bookmarks = [
              {
                name = "GitHub";
                url = "https://github.com";
              }
              {
                name = "NixOS Search";
                url = "https://search.nixos.org";
              }
            ];
          }
        ]
      '';
    };

    additionalExtensions = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Extension name (as used in the URL)";
              example = "youtube-nonstop";
            };
            id = lib.mkOption {
              type = lib.types.str;
              description = "Extension ID";
              example = "{0d7cafdd-501c-49ca-8ebb-e3341caaa55e}";
            };
          };
        }
      );
      default = [ ];
      description = "Additional extensions to install";
      example = [
        {
          name = "youtube-nonstop";
          id = "{0d7cafdd-501c-49ca-8ebb-e3341caaa55e}";
        }
      ];
    };

    downloadDirectory = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Download directory path";
    };

    neverTranslateLanguages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Languages to never translate";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.sessionVariables = {
      BROWSER = "firefox";
    };

    programs.gh.settings.browser = "firefox";

    home.file.".mozilla/managed-storage/uBlock0@raymondhill.net.json".text = builtins.toJSON {
      name = "uBlock0@raymondhill.net";
      description = "ignored";
      type = "storage";
      data = {
        adminSettings = builtins.toJSON {
          userSettings = {
            cloudStorageEnabled = true;
          };
        };
      };
    };

    programs.firefox = {
      enable = true;
      inherit (cfg) package;

      policies = lib.mkMerge [
        cfg.additionalPolicies
        {
          SearchEngines = {
            Add = developerSearchEngines;
            Remove = [
              "Bing"
              "eBay"
            ];
          };
          ExtensionSettings = builtins.listToAttrs (
            map (ext: mkExtension ext.name ext.id) (defaultExtensions ++ cfg.additionalExtensions)
          );
          DisableAppUpdate = true;
        }
      ];

      profiles.${cfg.profileName} = lib.mkMerge [
        {
          isDefault = true;

          settings = lib.mkMerge [
            defaultPrivacyPrefs
            (lib.mapAttrs (_: lib.mkDefault) defaultUxPrefs)
            {
              "services.sync.engine.addons" = true;
              "services.sync.engine.addons.ignoreDesktopClients" = false;
              "privacy.clearOnShutdown.cache" = false;
              "privacy.clearOnShutdown.cookies" = false;
              "privacy.clearOnShutdown.downloads" = false;
              "privacy.clearOnShutdown.formdata" = false;
              "privacy.clearOnShutdown.history" = false;
              "privacy.clearOnShutdown.sessions" = false;
              "privacy.sanitize.sanitizeOnShutdown" = false;
              "privacy.cpd.cache" = false;
              "privacy.cpd.cookies" = false;
              "privacy.cpd.formdata" = false;
              "privacy.cpd.history" = false;
              "privacy.cpd.sessions" = false;
            }
            (lib.optionalAttrs (cfg.downloadDirectory != null) {
              "browser.download.dir" = cfg.downloadDirectory;
              "browser.download.useDownloadDir" = true;
            })
            (lib.optionalAttrs (cfg.neverTranslateLanguages != [ ]) {
              "browser.translations.neverTranslateLanguages" =
                lib.concatStringsSep "," cfg.neverTranslateLanguages;
            })
            cfg.additionalPreferences
          ];
        }
        (lib.optionalAttrs (cfg.bookmarks != null) {
          bookmarks = import cfg.bookmarks;
        })
      ];
    };
  };
}
