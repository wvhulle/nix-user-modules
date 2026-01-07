{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.languages;

  topiary-nu-module = pkgs.topiary-nushell-queries;

  toolOptions = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable this tool";
    };
    package = lib.mkOption {
      type = lib.types.package;
      description = "Package providing the tool";
    };
    args = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional arguments to pass to the tool";
    };
  };

  toolType = lib.types.submodule { options = toolOptions; };

  serverType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable this tool";
      };
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Package providing the tool (null if externally managed)";
      };
      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional arguments to pass to the tool";
      };
      command = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Command to run the language server (defaults to package binary)";
      };
      config = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Configuration for the language server";
      };
    };
  };

  formatterType = lib.types.submodule {
    options = toolOptions // {
      command = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Command to run the formatter (defaults to package binary)";
      };
    };
  };

  debuggerType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable this debugger";
      };
      name = lib.mkOption {
        type = lib.types.str;
        description = "Name of the debugger (e.g., 'lldb-dap', 'gdb')";
      };
      transport = lib.mkOption {
        type = lib.types.enum [
          "stdio"
          "tcp"
        ];
        default = "stdio";
        description = "Transport protocol for the debugger";
      };
      command = lib.mkOption {
        type = lib.types.str;
        description = "Command to run the debugger";
      };
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Package providing the debugger";
      };
      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional arguments to pass to the debugger";
      };
      templates = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "Template name";
              };
              request = lib.mkOption {
                type = lib.types.enum [
                  "launch"
                  "attach"
                ];
                description = "Type of debug request";
              };
              completion = lib.mkOption {
                type = lib.types.listOf lib.types.anything;
                default = [ ];
                description = "Completion items for user prompts";
              };
              args = lib.mkOption {
                type = lib.types.attrs;
                default = { };
                description = "Debug adapter arguments";
              };
            };
          }
        );
        default = [ ];
        description = "Debug templates for this debugger";
      };
    };
  };

  typosServer = {
    package = pkgs.typos-lsp;
  };

  astGrepServer = {
    package = pkgs.ast-grep;
    args = [ "lsp" ];
  };

  languageType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable this language";
      };

      scope = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Tree-sitter scope identifier (e.g., 'source.rust')";
      };

      fileTypes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "File extensions for this language";
      };

      roots = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Root markers for language workspace detection";
      };

      formatter = lib.mkOption {
        type = lib.types.nullOr formatterType;
        default = null;
        description = "Formatter configuration for this language";
      };

      linter = lib.mkOption {
        type = lib.types.nullOr toolType;
        default = null;
        description = "Linter for this language";
      };

      debugger = lib.mkOption {
        type = lib.types.nullOr debuggerType;
        default = null;
        description = "Debugger for this language";
      };

      servers = lib.mkOption {
        type = lib.types.attrsOf serverType;
        default = { };
        description = "Language servers for this language";
      };

      compiler = lib.mkOption {
        type = lib.types.nullOr toolType;
        default = null;
        description = "Compiler for this language";
      };

      additionalPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional paths to add to PATH for this language";
      };

      additionalPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Additional packages to install for this language";
      };
    };
  };

  defaultLanguages = {
    nushell = {
      formatter = {
        package = pkgs.topiary;
        args = [
          "format"
          "--language"
          "nu"
        ];
      };
      linter.package = pkgs.nu-lint;
      servers = {

        nu = {
          package = pkgs.nushell;
          command = "nu";
          args = [
            "--lsp"
            "--no-config-file"
          ];
        };
        nu-lint = {
          package = pkgs.nu-lint;
          args = [ "--lsp" ];
        };
        typos-lsp = typosServer;
      };

      additionalPackages = [ pkgs.nu-lint ];
    };
    nix = {
      formatter.package = pkgs.nixfmt-rfc-style;
      servers = {
        nixd =
          let
            myFlake = ''(builtins.getFlake "/etc/nixos")'';
            hostName = "ryzen";
            nixosOpts = "${myFlake}.nixosConfigurations.${hostName}.options";
          in
          {
            command = "nixd";
            args = [ "--semantic-tokens=true" ];

            package = pkgs.nixd;
            config.nixd = {
              nixpkgs.expr = "import ${myFlake}.inputs.nixpkgs { }";
              formatting.command = [ "${lib.getExe pkgs.nixfmt-rfc-style}" ];
              options = {
                nixos.expr = nixosOpts;
                home-manager.expr = "${nixosOpts}.home-manager.users.type.getSubOptions []";
              };
            };
          };
        nil = {
          package = pkgs.nil;
        };
        typos-lsp = typosServer;
        ast-grep-lsp = astGrepServer;
      };
      additionalPackages = [ pkgs.nixpkgs-fmt ];
    };
    rust = {
      servers = {
        rust-analyzer = {
          config = {
            cachePriming.enable = true;
            imports.preferNoStd = true;
            lens.references.method.enable = true;
            completion.postfix.enable = false;
            diagnostics.experimental.enable = true;
            cargo = {
              allFeatures = true;
              allTargets = true;
            };
            check.command = lib.concatStrings [
              "clippy"
              "--"
              "-W clippy::pedantic"
              "-W clippy::nursery"
            ];
            procMacro = true;
          };
        };
        typos-lsp = typosServer;
        ast-grep-lsp = astGrepServer;
      };
      debugger = {
        name = "lldb-dap";
        transport = "stdio";
        package = pkgs.lldb;
        command = "lldb-dap";
        args = [ ];
        templates = [
          {
            name = "binary";
            request = "launch";
            completion = [
              {
                name = "binary";
                completion = "filename";
              }
            ];
            args = {
              program = "{0}";
            };
          }
          {
            name = "binary (terminal)";
            request = "launch";
            completion = [
              {
                name = "binary";
                completion = "filename";
              }
            ];
            args = {
              program = "{0}";
              runInTerminal = true;
            };
          }
          {
            name = "attach";
            request = "attach";
            completion = [ "pid" ];
            args = {
              pid = "{0}";
            };
          }
          {
            name = "gdbserver attach";
            request = "attach";
            completion = [
              {
                name = "lldb connect url";
                default = "connect://localhost:3333";
              }
              {
                name = "file";
                completion = "filename";
              }
              "pid"
            ];
            args = {
              attachCommands = [
                "platform select remote-gdb-server"
                "platform connect {0}"
                "file {1}"
                "attach {2}"
              ];
            };
          }
        ];
      };
      additionalPaths = [ "${config.home.homeDirectory}/.cargo/bin" ];
      additionalPackages = [
        pkgs.rustup
        pkgs.taplo
      ];
    };
    typst = {
      formatter.package = pkgs.typstyle;
      servers = {
        tinymist = {
          command = "tinymist";
          package = pkgs.tinymist;
          config.preview.background = {
            exportPdf = "onType";
            enabled = true;
            args = [
              "--data-plane-host=127.0.0.1:23635"
              "--open"
              "--invert-colors=auto"
            ];
          };
        };
        typos-lsp = typosServer;
        ast-grep-lsp = astGrepServer;
      };
      compiler.package = pkgs.typst;
    };
    markdown = {
      formatter = {
        package = pkgs.dprint;
        args = [
          "fmt"
          "--stdin"
        ];
      };
      servers.typos-lsp = typosServer;
      additionalPackages = [
        pkgs.zola
        pkgs.presenterm
      ];
    };
    cpp = {
      compiler.package = pkgs.clang;
      formatter = {
        package = pkgs.clang-tools;
        command = "clang-format";
      };
      linter = {
        package = pkgs.clang-tools;
        args = [ "--checks=*" ];
      };
      debugger = {
        name = "gdb";
        transport = "stdio";
        package = pkgs.gdb;
        command = "gdb";
        args = [ "--interpreter=mi" ];
        templates = [
          {
            name = "binary";
            request = "launch";
            completion = [
              {
                name = "binary";
                completion = "filename";
              }
            ];
            args = {
              console = "internalConsole";
              program = "{0}";
            };
          }
          {
            name = "binary (terminal)";
            request = "launch";
            completion = [
              {
                name = "binary";
                completion = "filename";
              }
            ];
            args = {
              program = "{0}";
              runInTerminal = true;
            };
          }
          {
            name = "attach";
            request = "attach";
            completion = [ "pid" ];
            args = {
              pid = "{0}";
            };
          }
          {
            name = "core dump";
            request = "launch";
            completion = [
              {
                name = "binary";
                completion = "filename";
              }
              {
                name = "core file";
                completion = "filename";
              }
            ];
            args = {
              program = "{0}";
              coreFile = "{1}";
            };
          }
          {
            name = "gdbserver attach";
            request = "attach";
            completion = [
              {
                name = "gdb connect url";
                default = "localhost:3333";
              }
              {
                name = "file";
                completion = "filename";
              }
              "pid"
            ];
            args = {
              attachCommands = [
                "target remote {0}"
                "file {1}"
                "attach {2}"
              ];
            };
          }
        ];
      };
      servers = {
        clangd = {
          package = pkgs.clang-tools;
          args = [
            "--background-index"
            "--query-driver=**/*clang++,**/*g++"
            "--header-insertion=never"
            "--completion-style=detailed"
            "--clang-tidy"
          ];
        };
        ast-grep-lsp = astGrepServer;
      };
      additionalPackages = [
        pkgs.cmake
        pkgs.gnumake
        pkgs.bear
        pkgs.gdb
        pkgs.watchexec
        pkgs.openssl
        pkgs.pkg-config
      ];
    };
    agda = {
      scope = "source.agda";
      fileTypes = [ "agda" ];
      roots = [ ".git" ];
      additionalPackages = [
        pkgs.agda
        pkgs.agdaPackages.standard-library
      ];
    };
    coq = {
      scope = "source.coq";
      fileTypes = [ "v" ];
      roots = [
        ".git"
        "_CoqProject"
      ];
      servers.vscoq = {
        package = pkgs.coqPackages.vscoq-language-server;
      };
      additionalPackages = [ pkgs.coq ];
    };
    haskell = {
      compiler.package = pkgs.haskell.compiler.ghc984;
      servers.hls = {
        package = pkgs.haskellPackages.haskell-language-server;
      };
      linter.package = pkgs.haskellPackages.hlint;
      additionalPackages = [
        pkgs.cabal-install
        pkgs.haskellPackages.ghcid
        pkgs.zlib
      ];
    };
    javascript = {
      servers = {
        typescript = {
          package = pkgs.typescript-language-server;
        };
        eslint = {
          package = pkgs.vscode-langservers-extracted;
        };
        ast-grep-lsp = astGrepServer;
      };
      additionalPackages = [
        pkgs.nodejs
        pkgs.deno
        pkgs.pnpm
      ];
    };
    lean = {
      scope = "source.lean";
      fileTypes = [ "lean" ];
      roots = [
        ".git"
        "lakefile.lean"
        "lean-toolchain"
      ];
      servers.lean4 = {
        command = "lake";
        args = [ "serve" ];
      };
      additionalPackages = [ pkgs.elan ];
    };
    nickel = {
      scope = "source.nickel";
      fileTypes = [ "ncl" ];
      roots = [ ".git" ];
      servers.nls = {
        package = pkgs.nls;
      };
      additionalPackages = [ pkgs.nickel ];
    };
    python = {
      servers.ast-grep-lsp = astGrepServer;
      additionalPackages = [
        pkgs.uv
      ];
      servers.ty = {
        package = pkgs.ty;
        command = "ty";
        args = [ "server" ];
      };
    };
    zig = {
      additionalPackages = [ pkgs.zvm ];
    };
  };

  enabledLanguages = lib.filterAttrs (_: l: l.enable) cfg.languages;

  allServers = lib.filter (s: s.package != null) (
    lib.flatten (
      lib.mapAttrsToList (
        _: lang: lib.attrValues (lib.filterAttrs (_: s: s.enable) lang.servers)
      ) enabledLanguages
    )
  );

  allFormatters = lib.filter (f: f != null && f.enable) (
    lib.mapAttrsToList (_: lang: lang.formatter) enabledLanguages
  );

  allLinters = lib.filter (l: l != null && l.enable) (
    lib.mapAttrsToList (_: lang: lang.linter) enabledLanguages
  );

  allCompilers = lib.filter (c: c != null && c.enable) (
    lib.mapAttrsToList (_: lang: lang.compiler) enabledLanguages
  );

  allDebuggers = lib.filter (d: d != null && d.enable) (
    lib.mapAttrsToList (_: lang: lang.debugger) enabledLanguages
  );

  allAdditionalPaths = lib.flatten (
    lib.mapAttrsToList (_: lang: lang.additionalPaths) enabledLanguages
  );

  allAdditionalPackages = lib.flatten (
    lib.mapAttrsToList (_: lang: lang.additionalPackages) enabledLanguages
  );
in
{
  options.programs.languages = {
    enable = lib.mkEnableOption "unified language toolchain configuration";

    languages = lib.mkOption {
      type = lib.types.attrsOf languageType;
      default = defaultLanguages;
      description = "Language toolchain configurations";
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      topiary = {
        enable = true;
        languages.nu = {
          extensions = [ "nu" ];
          queryFile = "${topiary-nu-module}/languages/nu.scm";
          grammar.source.git = {
            git = "https://github.com/nushell/tree-sitter-nu.git";
            rev = "18b7f951e0c511f854685dfcc9f6a34981101dd6";
          };
        };
      };
    };

    home = {
      sessionPath = allAdditionalPaths;

      packages =
        (map (s: s.package) allServers)
        ++ (map (f: f.package) allFormatters)
        ++ (map (l: l.package) allLinters)
        ++ (map (c: c.package) allCompilers)
        ++ (map (d: d.package) allDebuggers)
        ++ allAdditionalPackages;
    };
  };
}
