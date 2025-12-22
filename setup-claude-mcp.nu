#!/usr/bin/env nu

# Merge MCP server configuration into ~/.claude.json (user scope)
# This script updates user-scoped MCP server configuration
# and only writes if there are actual changes.
def main [
  --mcp-config: string # JSON string containing MCP configuration
]: nothing -> nothing {
  let json_path = $env.HOME | path join '.claude.json'

  ensure-config-exists $json_path

  let new_servers = $mcp_config | from json | get mcpServers
  let existing_config = open $json_path
  let existing_servers = $existing_config | get mcpServers | default {}

  if (has-changes $new_servers $existing_servers) {
    update-and-report $json_path $existing_config $existing_servers $new_servers
  } else {
    print $"<notice>MCP servers already up to date in ($json_path)"
  }
}

# Ensure the configuration file exists
def ensure-config-exists [json_path: path]: nothing -> nothing {
  if not ($json_path | path exists) {
    {} | to json | save $json_path
    print $"<info>Created ($json_path)"
  }
}

# Check if there are any changes to apply
def has-changes [
  new_servers: record
  existing_servers: record
]: nothing -> bool {
  $new_servers
  | items {|name config|
    let existing = $existing_servers | get -o $name
    $existing == null or $existing != $config
  }
  | any {|x| $x }
}

# Update configuration and report changes
def update-and-report [
  json_path: path
  existing_config: record
  existing_servers: record
  new_servers: record
]: nothing -> nothing {
  let merged_servers = $existing_servers | merge $new_servers

  $existing_config
  | upsert mcpServers $merged_servers
  | to json
  | save --force $json_path

  print $"<info>Updated user-scoped MCP servers in ($json_path)"

  report-changes $existing_servers $new_servers
}

# Report what was added or updated
def report-changes [
  existing_servers: record
  new_servers: record
]: nothing -> nothing {
  $new_servers
  | items {|name _config|
    if ($existing_servers | get -o $name) == null {
      $"<info>  - Added: ($name)"
    } else {
      $"<info>  - Updated: ($name)"
    }
  }
  | each {|msg| print $msg }
}
