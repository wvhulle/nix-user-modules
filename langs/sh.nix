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
    "When printing errors, consider writing to either stdout or stderr."
    "Prefix shell script output with journald priority levels as <level>."
    "Consider using Nushell for new scripts instead of bash."
  ];
}
