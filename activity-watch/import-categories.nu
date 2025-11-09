#!/usr/bin/env nu

# ActivityWatch Categories Import Script
# Clears existing categories and imports new ones from the provided JSON file

def main [
  categories_file: path # Path to the categories JSON file
  --port (-p): int = 5600 # ActivityWatch server port
] {
  let server_url = $"http://localhost:($port)"

  print "ActivityWatch Categories Import"
  print $"Server: ($server_url)"
  print $"Categories file: ($categories_file)"

  # Check if server is running
  try {
    let status = (curl -s $"($server_url)/api/0/info" | from json)
    print $"Server version: ($status.version)"
  } catch {
    print "Error: ActivityWatch server is not running or not accessible"
    exit 1
  }

  # Check if categories file exists
  if not ($categories_file | path exists) {
    print $"Error: Categories file not found: ($categories_file)"
    exit 1
  }

  print "Reading new categories..."
  let new_categories = try {
    open $categories_file
  } catch {
    print $"Error: Failed to read categories file"
    exit 1
  }

  print "Updating settings with new categories..."
  # The frontend expects 'classes' field, not 'rules'

  try {
    $new_categories | to json | curl -s -X POST -H "Content-Type: application/json" -d @- $"($server_url)/api/0/settings/classes" | ignore
    print "✓ Categories updated successfully!"

    # Verify import by checking count
    let imported = (curl -s $"($server_url)/api/0/settings/classes" | from json)
    print $"✓ Total categories imported: ($imported.classes | length)"
  } catch {
    print "Error: Failed to update settings"
    exit 1
  }
}
