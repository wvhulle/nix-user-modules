{
  lib,
  pkgs,
  config,
  typosServer,
  astGrepServer,
}:

{
  scope = "source.rust";
  extensions = [ "rs" ];
  instructions = [
    "Never use the `anyhow` dependency."
    "Never use the `String` type for building error types or enum variants."
    "Only make code `pub` or `pub(crate)` when necessary."
    "Use `Result` and `Option` consistently instead of panicking."
    "Use the `clippy` linter to improve code quality."
    "Write new tests for public API inside the tests/ folder"
    "Write new unit tests for private API inside the relevant src file"
    "Use extension traits to group together related methods that are always called on the same (first) argument type."
    "Fix a large portion of clippy problems automatically with `cargo clippy --all-targets --fix --allow-dirty`."
    "Instead of adding comments that become stale, add logging with the external `log` crate and its macros."
    "Do not create unit structs."
    "Don't make internal modules public."
    "Never use programming language-specific words like `types`, `trait`, `functions`, or `variables` in module or variable names."
  ];

  terminalCommands.cargo = {
    autoApprove = true;
    exactCommands = [ ];
    regexPatterns = [ "/^cargo\\s+(test|build|check|clippy|fmt|doc|run)\\b/" ];
  };

  servers = {
    rust-analyzer = {
      package = pkgs.rust-analyzer;
      config = {
        cachePriming.enable = true;
        lens.references.method.enable = true;
        imports.preferNoStd = false; # Only enable for embedded, will cause errors when writing std macro's otherwise.
        completion.postfix.enable = false;
        diagnostics.experimental.enable = true;
        cargo = {
          allFeatures = true;
          allTargets = true;
        };
        rustfmt = {
          rangeFormatting.enable = true;
          extraArgs = [
            "--unstable-features"
            "--config"
            (lib.concatStringsSep "," [
              "group_imports=StdExternalCrate"
              "imports_granularity=Crate"
              "use_field_init_shorthand=true"
              "format_code_in_doc_comments=true"
              "normalize_doc_attributes=true"
            ])
          ];
        };
        check = {
          command = "clippy";
          extraArgs = [
            "--"
            "-W"
            "clippy::pedantic"
            "-W"
            "clippy::nursery"
          ];
        };
        procMacro.enable = true;
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
        args.program = "{0}";
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
        args.pid = "{0}";
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
        args.attachCommands = [
          "platform select remote-gdb-server"
          "platform connect {0}"
          "file {1}"
          "attach {2}"
        ];
      }
    ];
  };

  additionalPaths = [ "${config.home.homeDirectory}/.cargo/bin" ];
  additionalPackages = [
    pkgs.taplo
    pkgs.rustup
  ];
}
