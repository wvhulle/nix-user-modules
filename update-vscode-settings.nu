#!/usr/bin/env nu

# Update VSCode settings.json with writable file from Nix configuration
# This script is used by Home Manager activation to create/update the settings file

def main [source_file: path] {
  let settings_file = $"($env.HOME)/.config/Code/User/settings.json"

  mkdir ($settings_file | path dirname)

  let should_update = (
    not ($settings_file | path exists)
    or ($settings_file | path type) == "symlink"
    or (open --raw $source_file) != (open --raw $settings_file)
  )

  if $should_update {
    rm --force $settings_file
    cp $source_file $settings_file
    chmod 644 $settings_file
    print "Created/updated writable VSCode settings.json"
  }
}
