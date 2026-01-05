#!/usr/bin/env nu

# Migrate syncthing configuration from old location to new XDG-compliant location
# This script creates symlinks from the new location to the old location,
# ensuring syncthing can find its config regardless of which path it uses.

def main [
  --old-config: path = "~/.config/syncthing" # Old syncthing config directory
  --new-config: path = "~/.local/state/syncthing" # New syncthing config directory
  --dry-run # Show what would be done without making changes
] {
  let old_config = $old_config | path expand
  let new_config = $new_config | path expand

  if not ($old_config | path exists) {
    print "<6>Syncthing old config directory does not exist, skipping migration"
    return
  }

  mkdir $new_config

  let files_to_migrate = [
    "config.xml"
    "cert.pem"
    "key.pem"
    "https-cert.pem"
    "https-key.pem"
  ]

  for file in $files_to_migrate {
    let old_file = $old_config | path join $file
    let new_file = $new_config | path join $file

    if ($old_file | path exists) {
      migrate-file $old_file $new_file --dry-run=$dry_run
    }
  }

  let old_index = $old_config | path join "index-v2"
  let new_index = $new_config | path join "index-v2"

  if ($old_index | path exists) and not ($new_index | path exists) {
    migrate-file $old_index $new_index --dry-run=$dry_run
  }

  mkdir ($"($env.HOME)/Sync" | path expand)
}

# Migrate a single file or directory by creating a symlink
def migrate-file [
  old_path: path
  new_path: path
  --dry-run
] {
  if not ($new_path | path exists) {
    if $dry_run {
      print $"<6>Would create symlink: ($new_path) -> ($old_path)"
    } else {
      ln -s $old_path $new_path
      print $"<6>Created symlink for syncthing ($old_path | path basename)"
    }
  } else if ($new_path | path type) == "symlink" {
    let current_target = ls -l $new_path | get target.0
    if $current_target != $old_path {
      if $dry_run {
        print $"<6>Would update symlink: ($new_path) -> ($old_path)"
      } else {
        rm $new_path
        ln -s $old_path $new_path
        print $"<6>Updated symlink for syncthing ($old_path | path basename)"
      }
    }
  }
}
