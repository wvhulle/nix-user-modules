_:

{
  scope = "source.bash";
  extensions = [
    "sh"
    "bash"
  ];
  instructions = [
    "Do not create functions in scripts that are just one line (excluding comments)."
    "Lint bash script files with ShellCheck linter and fix issues."
    "Consider using Nushell for new scripts instead of bash."
    "You should never capture or redirect stdout or stderr output unless necessary."
  ];
}
