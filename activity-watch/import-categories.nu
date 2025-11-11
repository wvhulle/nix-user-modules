#!/usr/bin/env nu

def main [
  categories_file: path
  --port (-p): int = 5600
] {
  let server_url = $"http://localhost:($port)"

  print $"ActivityWatch Categories Import\nServer: ($server_url)\nCategories file: ($categories_file)\n"

  let status = try {
    http get $"($server_url)/api/0/info"
  } catch {
    print "Error: ActivityWatch server is not running or not accessible"
    exit 1
  }
  print $"Server version: ($status.version)"

  if not ($categories_file | path exists) {
    print $"Error: Categories file not found: ($categories_file)"
    exit 1
  }

  print "Reading new categories..."
  let new_categories = try {
    open $categories_file
  } catch {
    print "Error: Failed to read categories file"
    exit 1
  }

  print "Updating settings with new categories..."
  try {
    http post --content-type application/json $"($server_url)/api/0/settings/classes" $new_categories | ignore

    let imported = http get $"($server_url)/api/0/settings/classes"
    let count = $imported | length

    print $"✓ Categories updated successfully!\n✓ Total categories imported: ($count)"
  } catch {
    print "Error: Failed to update settings"
    exit 1
  }
}
