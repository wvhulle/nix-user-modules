#!/usr/bin/env nu

# Fix VS Code Extensions
# This script attempts to make the user's extensions directory writable
# but skips entries that are symlinks (typically Nix-managed) and
# continues on errors so Home Manager activation doesn't fail on read-only
# filesystems.

# Check if a path is a symlink
def is-symlink [path: path]: nothing -> bool {
  # Try to read symlink metadata - if it has a target, it's a symlink

  let result = (do -i { ls -l $path | get target.0? })
  $result != null
}

# Get the VS Code extensions directory path
def get-extensions-dir []: nothing -> path {
  $env.HOME | path join ".vscode" "extensions"
}

# Fix permissions for a single extension directory
def fix-extension-permissions [ext_path: path]: nothing -> nothing {
  if (is-symlink $ext_path) {
    print $"  Skipping symlink: ($ext_path)"
    return
  }

  try {
    chmod -R u+w $ext_path
    print $"  Fixed permissions: ($ext_path)"
  } catch {
    print $"  Could not chmod (skipping): ($ext_path)"
  }
}

# Main function to fix all VS Code extension permissions
def main []: nothing -> nothing {
  print "Fixing VS Code extensions permissions (skipping symlinks)..."

  let vscode_dir = (get-extensions-dir)

  # Check if directory exists
  if not ($vscode_dir | path exists) {
    print $"VS Code extensions directory not found: ($vscode_dir)"
    return
  }

  # Get all extension directories
  try {
    ls $vscode_dir
    | where type == dir
    | get name
    | each {|ext_path| fix-extension-permissions $ext_path }
    | ignore

    print "Done attempting to fix VS Code extensions permissions"
  } catch {|err|
    # Do not fail activation if something goes wrong; just warn
    print $"Warning: could not process VS Code extensions: ($err.msg)"
  }
}
