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

  commands = {
    test = {
      description = "Run Rust tests with detailed error output";
      prompt = ''
        Run the full test suite using `cargo test`.
        If tests fail:
        1. Analyze the error messages
        2. Identify the root cause
        3. Suggest specific fixes

        Focus on:
        - Test assertion failures
        - Compilation errors in test code
        - Missing trait implementations
        - Lifetime or borrow checker issues
      '';
      allowedTools = [
        "Bash(cargo:*)"
        "Read(//)"
      ];
      argumentHint = "[test-name-pattern]";
    };

    clippy = {
      description = "Run clippy and apply fixes";
      prompt = ''
        1. Run `cargo clippy --all-targets --fix --allow-dirty`
        2. Review the automated changes
        3. For remaining warnings, explain and suggest manual fixes
        4. Prioritize fixes by severity (deny > warn > allow)
      '';
      allowedTools = [
        "Bash(cargo:*)"
        "Read(//)"
        "Edit(//)"
      ];
    };

    add-error = {
      description = "Add a new error type following Rust best practices";
      prompt = ''
        Create a new error type in the specified module that:
        - Uses `thiserror` derive macro (never `anyhow`)
        - Has descriptive variant names
        - Includes context in error messages
        - Implements proper error chaining with `#[from]`
        - Uses `&'static str` for fixed messages, not `String`

        Example structure:
        ```rust
        use thiserror::Error;

        #[derive(Error, Debug)]
        pub enum YourError {
            #[error("descriptive message: {0}")]
            Variant(#[from] SourceError),
        }
        ```
      '';
      argumentHint = "<module-path>";
      allowedTools = [
        "Read(//)"
        "Edit(//)"
        "Write(//)"
      ];
    };

    bench = {
      description = "Run benchmarks and analyze performance";
      prompt = ''
        1. Run `cargo bench` to execute benchmarks
        2. Analyze the results
        3. Identify performance bottlenecks
        4. Suggest optimizations based on the metrics
      '';
      allowedTools = [
        "Bash(cargo:*)"
        "Read(//)"
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
