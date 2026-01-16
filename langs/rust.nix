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
    "Use extension traits to group together related methods that are always called on the same (first) argument type."
    "Never add new code using `anyhow`."
  ];

  commands = {
    test = {
      description = "Run cargo test and fix failures";
      prompt = "Run `cargo test`. Analyze failures and suggest fixes.";
      allowedTools = [
        "Bash(cargo:*)"
        "Read(//)"
      ];
      argumentHint = "[test-name-pattern]";
    };

    clippy = {
      description = "Run clippy and apply fixes";
      prompt = "Run `cargo clippy --all-targets --fix --allow-dirty`. Fix remaining warnings.";
      allowedTools = [
        "Bash(cargo:*)"
        "Read(//)"
        "Edit(//)"
      ];
    };
  };

  terminalCommands.cargo = {
    autoApprove = true;
    exactCommands = [ ];
    regexPatterns = [ "/^cargo\\s+(test|build|check|clippy|fmt|doc|run)\\b/" ];
  };

  servers = {
    rust-analyzer = {
      # You probably never want to hard-code the rust-analyzer version to Nix since Rust toolchains are rolling
      # command = pkgs.lib.getExe pkgs.rust-analyzer;
      config = {
        cachePriming.enable = true; # Disabled since it may cause slow downs
        lens.references.method.enable = true;
        imports.preferNoStd = false; # Only enable for embedded, will cause errors when writing std macro's otherwise.
        completion.postfix.enable = false;
        diagnostics = {
          enable = false; # Bug in Rust-analyzer flags used variables with `unused_variables` violation, just use the Clippy diagnostics configured with check.command.
        };
        cargo = {
          allFeatures = true;
          allTargets = true;
          sysroot = "discover";
        };
        rustfmt = {
          rangeFormatting.enable = true;
          extraArgs = [
            "--config"
            (lib.concatStringsSep "," [
              "unstable_features=true"
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
          # Keep disabled if you want to have clippy configured per project
          # extraArgs = [
          #   "--"
          #   "-W"
          #   "clippy::pedantic"
          #   "-W"
          #   "clippy::nursery"
          #   "-W"
          #   "clippy::absolute_paths"
          #   "-W"
          #   "clippy::redundant_pub_crate"

          # ];
        };
        procMacro.enable = true;
      };
    };
    typos-lsp = typosServer;
    ast-grep-lsp = astGrepServer;
    # TODO switch to backtrace-ls
    # assert-lsp = {
    #   command = "assert-lsp";
    #   config = {

    #   };
    # };
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
    pkgs.openssl
    pkgs.pkg-config
  ];
}
