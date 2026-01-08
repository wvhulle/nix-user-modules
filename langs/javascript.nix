{
  pkgs,
  astGrepServer,
}:

{
  scope = "source.js";
  extensions = [
    "js"
    "mjs"
    "cjs"
  ];

  terminalCommands.npm = {
    autoApprove = true;
    exactCommands = [
      "make"
      "npm test"
      "npm run test"
    ];
    regexPatterns = [ "/^npm\\s+(test|run\\s+test|run\\s+build|install|ci)\\b/" ];
  };

  servers = {
    typescript.package = pkgs.typescript-language-server;

    eslint = {
      package = pkgs.vscode-langservers-extracted;
      command = "vscode-eslint-language-server";
      args = [ "--stdio" ];
      config = {
        validate = "on";
        packageManager = "yarn";
        useESLintClass = false;
        codeActionOnSave.mode = "all";
        format = true;
        quiet = false;
        onIgnoredFiles = "off";
        rulesCustomizations = [ ];
        run = "onType";
        nodePath = "";
        workingDirectory.mode = "auto";
        experimental = { };
        problems.shortenToSingleLine = false;
        codeAction = {
          disableRuleComment = {
            enable = true;
            location = "separateLine";
          };
          showDocumentation.enable = true;
        };
      };
    };

    ast-grep-lsp = astGrepServer;
  };

  additionalPackages = [
    pkgs.nodejs
    pkgs.deno
    pkgs.pnpm
  ];
}
