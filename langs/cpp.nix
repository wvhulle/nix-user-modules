{
  pkgs,
  astGrepServer,
}:

{
  scope = "source.cpp";
  extensions = [
    "cpp"
    "cc"
    "cxx"
    "c"
    "h"
    "hpp"
  ];

  compiler.package = pkgs.clang;

  formatter = {
    package = pkgs.clang-tools;
    command = "clang-format";
  };

  linter = {
    package = pkgs.clang-tools;
    args = [ "--checks=*" ];
  };

  servers = {
    clangd = {
      package = pkgs.clang-tools;
      command = "clangd";
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
        args.pid = "{0}";
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
        args.attachCommands = [
          "target remote {0}"
          "file {1}"
          "attach {2}"
        ];
      }
    ];
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
}
