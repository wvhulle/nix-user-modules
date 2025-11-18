{
  config,
  lib,
  pkgs,
  unstable ? pkgs,
  ...
}:

let
  cfg = config.programs.firefox-extended;

  generateServerBookmarks =
    {
      webServices,
      machines,
      currentHostname,
    }:
    {
      name = "Server";
      bookmarks =
        (lib.flatten (
          lib.mapAttrsToList (
            hostname: hostConfig:
            let
              hostServiceNames = hostConfig.webServices or [ ];
              hostServices = map (serviceName: webServices.${serviceName} // { name = serviceName; }) (
                lib.filter (
                  serviceName: webServices ? ${serviceName} && (webServices.${serviceName}.htmlAccess or false)
                ) hostServiceNames
              );
            in
            lib.map (service: {
              name = "${service.name} (${hostname})";
              url = "http://${service.subdomain}.${hostname}.local";
            }) hostServices
          ) machines
        ))
        ++ [
          {
            name = "Service Directory (${currentHostname})";
            url = "http://${currentHostname}.local/";
          }
        ];
    };

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
  };
in
{
  options.programs.firefox-extended = {
    enable = lib.mkEnableOption "extended firefox configuration";

    package = lib.mkOption {
      type = lib.types.package;
      default = unstable.firefox;
      defaultText = lib.literalExpression "unstable.firefox";
      description = "Firefox package to use";
    };

    enablePrivacyPresets = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable privacy and security presets";
    };

    enableUxPresets = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable user experience presets";
    };

    preserveUserData = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to preserve user data on shutdown";
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
    };

    enableServerBookmarks = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to automatically generate server bookmarks from network configuration";
    };

    webServices = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Web services configuration (system-level config passed through)";
    };

    machines = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Machine configurations (system-level config passed through)";
    };

    currentHostname = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      description = "Current hostname for service directory bookmark";
    };

    enableDeveloperSearchEngines = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to add useful search engines for developers (NixOS packages, Home Manager options, etc.)";
    };

    enableDeveloperExtensions = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable developer-oriented extensions";
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

    uBlockOrigin = {
      enable = lib.mkEnableOption "uBlock Origin configuration";

      userFilters = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Custom uBlock Origin user filters.

          IMPORTANT: Firefox must be completely closed BEFORE running home-manager/nixos-rebuild switch.
          If Firefox is running during the rebuild, it may overwrite the managed storage file on shutdown,
          causing the new filters to not take effect even after restart.
        '';
        example = [
          "bandcamp.com##.factoid.corp-page-section.global-section"
          "youtube.com##.ytp-pause-overlay"
        ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.sessionVariables = {
      BROWSER = "firefox";
    };

    programs.gh.settings.browser = "firefox";

    home.file = lib.mkIf (cfg.uBlockOrigin.enable || cfg.uBlockOrigin.userFilters != [ ]) {
      ".mozilla/managed-storage/uBlock0@raymondhill.net.json".text = builtins.toJSON {
        name = "uBlock0@raymondhill.net";
        description = "ignored";
        type = "storage";
        data = {
          adminSettings = builtins.toJSON {
            userFilters = lib.concatStringsSep "\n" cfg.uBlockOrigin.userFilters;
          };
        };
      };
    };

    programs.firefox = {
      enable = true;
      inherit (cfg) package;

      policies = lib.mkMerge [
        cfg.additionalPolicies
        (lib.optionalAttrs cfg.enableDeveloperSearchEngines {
          SearchEngines = {
            Add = developerSearchEngines;
            Remove = [
              "Bing"
              "eBay"
            ];
          };
        })
        (lib.optionalAttrs (cfg.additionalExtensions != [ ]) {
          ExtensionSettings = builtins.listToAttrs (
            map (ext: mkExtension ext.name ext.id) cfg.additionalExtensions
          );
        })
      ];

      profiles.${cfg.profileName} = lib.mkMerge [
        {
          isDefault = true;

          settings = lib.mkMerge [
            (lib.optionalAttrs cfg.enablePrivacyPresets defaultPrivacyPrefs)
            (lib.optionalAttrs cfg.enableUxPresets (lib.mapAttrs (_: lib.mkDefault) defaultUxPrefs))
            (lib.optionalAttrs cfg.preserveUserData {
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
            })
            cfg.additionalPreferences
          ];
        }
        (lib.optionalAttrs (cfg.bookmarks != null) (
          let
            baseBookmarks = import cfg.bookmarks;

            finalBookmarks =
              if cfg.enableServerBookmarks then
                {
                  inherit (baseBookmarks) force;
                  settings = lib.map (
                    toolbar:
                    toolbar
                    // {
                      bookmarks = toolbar.bookmarks ++ [
                        (generateServerBookmarks {
                          inherit (cfg) webServices;
                          inherit (cfg) machines;
                          inherit (cfg) currentHostname;
                        })
                      ];
                    }
                  ) baseBookmarks.settings;
                }
              else
                baseBookmarks;
          in
          {
            bookmarks = finalBookmarks;
          }
        ))
      ];
    };
  };
}
