{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.firefox-extended;

  flattenAttrs =
    let
      isLeaf = value: !lib.isAttrs value || (value ? Value) || (value ? Status);

      flatten =
        prefix: set:
        lib.concatLists (
          lib.mapAttrsToList (
            name: value:
            let
              key = if prefix == "" then name else "${prefix}.${name}";
            in
            if name == "_self" then
              [
                {
                  key = prefix;
                  inherit value;
                }
              ]
            else if isLeaf value then
              [ { inherit key value; } ]
            else
              flatten key value
          ) set
        );
    in
    set:
    builtins.listToAttrs (
      map (x: {
        name = x.key;
        inherit (x) value;
      }) (flatten "" set)
    );

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
    {
      Name = "GitHub Code Search";
      URLTemplate = "https://github.com/search?q={searchTerms}&type=code";
      Method = "GET";
      IconURL = "https://github.com/favicon.ico";
      Alias = "@gh";
      Description = "Search code on GitHub";
    }
    {
      Name = "Crates.io";
      URLTemplate = "https://crates.io/search?q={searchTerms}";
      Method = "GET";
      IconURL = "https://crates.io/favicon.ico";
      Alias = "@crates";
      Description = "Search Rust crates";
    }
    {
      Name = "Sourcegraph";
      URLTemplate = "https://sourcegraph.com/search?q={searchTerms}";
      Method = "GET";
      IconURL = "https://sourcegraph.com/favicon.ico";
      Alias = "@sg";
      Description = "Search code on Sourcegraph";
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
      name = "ublock-origin";
      id = "uBlock0@raymondhill.net";
    }
    {
      name = "clearurls";
      id = "{74145f27-f039-47ce-a470-a662b129930a}";
    }
    {
      name = "bitwarden-password-manager";
      id = "{446900e4-71c2-419f-a6a7-df9c091e268b}";
    }
    {
      name = "darkreader";
      id = "addon@darkreader.org";
    }
    {
      name = "flagfox";
      id = "{1018e4d6-728f-4b20-ad56-37578a4de76b}";
    }
    {
      name = "to-google-translate";
      id = "jid1-93WyvpgvxzGATw@jetpack";
    }
    {
      name = "feedbro";
      id = "{a9c2ad37-e940-4892-8dce-cd73c6cbbc0c}";
    }
    {
      name = "adaptive-tab-bar-colour";
      id = "ATBC@EasonWong";
    }
    {
      name = "livemarks";
      id = "{c5867acc-54c9-4074-9574-04d8818d53e8}";
    }
    {
      name = "songlink";
      id = "songlink@song.link";
    }
    {
      name = "auto-tab-discard";
      id = "{c2c003ee-bd69-42a2-b0e9-6f34222cb046}";
    }
    {
      name = "aw-watcher-web";
      id = "{ef87d84c-2127-493f-b952-5b4e744245bc}";
    }
    {
      name = "consent-o-matic";
      id = "gdpr@cavi.au.dk";
    }
    {
      name = "giphy-for-firefox";
      id = "gt@giphy.com";
    }
    {
      name = "terms-of-service-didnt-read";
      id = "jid0-3GUEt1r69sQNSrca5p8kx9Ezc3U@jetpack";
    }
    {
      name = "privacy-badger17";
      id = "jid1-MnnxcxisBPnSXQ@jetpack";
    }
    {
      name = "search_by_image";
      id = "{2e5ff8c8-32fe-46d0-9fc8-6b8986621f3c}";
    }
    {
      name = "video-downloadhelper";
      id = "{b9db16a4-6edc-47ec-a1f4-b86292ed211d}";
    }
    {
      name = "youtube-recommended-videos";
      id = "myallychou@gmail.com";
    }
    {
      name = "youtube-nonstop";
      id = "{0d7cafdd-501c-49ca-8ebb-e3341caaa55e}";
    }
    {
      name = "read-aloud";
      id = "{ddc62400-f22d-4dd3-8b4a-05837de53c2e}";
    }
  ];

  defaultPreferences = {
    browser = {
      contentblocking.category = {
        Value = "strict";
        Status = "locked";
      };
      newtabpage = {
        enabled = false;
        activity-stream = {
          feeds = {
            topsites = false;
            telemetry = false;
          };
          showSponsoredTopSites = false;
          telemetry = false;
        };
      };
      formfill.enable = false;
      urlbar.suggest.searches = true;
      tabs = {
        warnOnClose = false;
        warnOnCloseOtherTabs = false;
        loadInBackground = true;
        insertAfterCurrent = true;
        crashReporting.sendReport = false;
      };
      crashReports = {
        unsubmittedCheck = {
          enabled = false;
          autoSubmit2 = false;
        };
      };
      sessionstore.resume_from_crash = true;
      startup = {
        page = 3;
        homepage = "about:blank";
      };
      ping-centre.telemetry = false;
      translations.neverTranslateLanguages = "nl";
    };
    privacy = {
      trackingprotection = {
        enabled = true;
        socialtracking.enabled = true;
        cryptomining.enabled = true;
        fingerprinting.enabled = true;
      };
      clearOnShutdown = {
        cache = false;
        cookies = false;
        downloads = false;
        formdata = false;
        history = false;
        sessions = false;
      };
      sanitize.sanitizeOnShutdown = false;
      cpd = {
        cache = false;
        cookies = false;
        formdata = false;
        history = false;
        sessions = false;
      };
    };
    security = {
      tls.version.min = 3;
      ssl.require_safe_negotiation = true;
    };
    services.sync.engine.addons = {
      _self = false;
      ignoreDesktopClients = true;
    };
    signon = {
      rememberSignons = false;
      autofillForms = false;
      generation.enabled = false;
      management.page.breach-alerts.enabled = false;
    };
    extensions.pocket.enabled = false;
    devtools = {
      theme = "dark";
      toolbox.host = "bottom";
    };
    datareporting = {
      healthreport.uploadEnabled = false;
      policy.dataSubmissionEnabled = false;
    };
    toolkit.telemetry = {
      enabled = false;
      unified = false;
      archive.enabled = false;
    };
    breakpad.reportURL = "";
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
      description = ''
        Additional Firefox preferences. Can be specified as nested attribute sets
        which will be flattened to dot-notation. Use `_self` to set a value at a
        level that also has nested attributes.
      '';
      example = lib.literalExpression ''
        {
          browser.tabs.closeWindowWithLastTab = false;
          privacy.donottrackheader.enabled = true;
          services.sync.engine = {
            history = true;
            bookmarks = {
              _self = true;
              ignoreDesktopClients = false;
            };
          };
        }
      '';
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
      nativeMessagingHosts = with pkgs; [ kdePackages.plasma-browser-integration ];

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

      profiles.${cfg.profileName} = {
        isDefault = true;
        settings = lib.mkMerge [
          (flattenAttrs defaultPreferences)
          (flattenAttrs cfg.additionalPreferences)
        ];
      }
      // lib.optionalAttrs (cfg.bookmarks != null) { bookmarks = import cfg.bookmarks; };
    };
  };
}
