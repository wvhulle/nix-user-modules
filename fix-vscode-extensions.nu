#!/usr/bin/env nu

# Fix VS Code Extensions
# This script attempts to make the user's extensions directory writable
# but skips entries that are symlinks (typically Nix-managed) and
# continues on errors so Home Manager activation doesn't fail on read-only
# filesystems.

def is-symlink [path: path]: nothing -> bool {

  let result = (do -i { ls -l $path | get target.0? })
  $result != null
}

def get-extensions-dir []: nothing -> path {
  $env.HOME | path join ".vscode" "extensions"
}

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

def main []: nothing -> nothing {
  print "Fixing VS Code extensions permissions (skipping symlinks)..."

  let vscode_dir = (get-extensions-dir)

  if not ($vscode_dir | path exists) {
    print $"VS Code extensions directory not found: ($vscode_dir)"
    return
  }

  try {
    ls $vscode_dir
    | where type == dir
    | get name
    | each {|ext_path| fix-extension-permissions $ext_path }
    | ignore

    print "Done attempting to fix VS Code extensions permissions"
  } catch {|err|
    print $"Warning: could not process VS Code extensions: ($err.msg)"
  }
}
