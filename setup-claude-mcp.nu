#!/usr/bin/env nu

# Merge MCP server configuration into ~/.claude.json (user scope)
# This script updates user-scoped MCP server configuration
# and only writes if there are actual changes.
def main [
  --mcp-config: string # JSON string containing MCP configuration
]: nothing -> nothing {
  let mcp_config = if $mcp_config == null {
    error make {
      msg: "--mcp-config is required"
      help: "Pass a JSON string with mcpServers configuration: --mcp-config '{\"mcpServers\": {...}}'"
    }
  } else {
    $mcp_config
  }

  let json_path = $env.HOME | path join .claude.json

  ensure-config-exists $json_path

  let new_servers = $mcp_config | from json | get mcpServers
  let existing_config = open $json_path
  let existing_servers = $existing_config | get mcpServers | default {}

  if (has-changes $new_servers $existing_servers) {
    {
      json_path: $json_path
      existing_config: $existing_config
      existing_servers: $existing_servers
      new_servers: $new_servers
    } | update-and-report
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
  let has_updates = $new_servers
    | items {|name config|
      let existing = $existing_servers | get -o $name
      $existing == null or $existing != $config
    }
    | any {|x| $x }

  let has_removals = $existing_servers
    | columns
    | any {|name| ($new_servers | get -o $name) == null }

  $has_updates or $has_removals
}

# Update configuration and report changes
def update-and-report []: record -> nothing {
  let ctx = $in
  # Replace entirely with new servers (removes servers not in new config)
  $ctx.existing_config
  | upsert mcpServers $ctx.new_servers
  | to json
  | save --force $ctx.json_path

  print $"<info>Updated user-scoped MCP servers in ($ctx.json_path)"

  report-changes $ctx.existing_servers $ctx.new_servers
}

# Report what was added, updated, or removed
def report-changes [
  existing_servers: record
  new_servers: record
]: nothing -> nothing {
  # Report added or updated servers
  for entry in ($new_servers | items {|name config| {name: $name config: $config} }) {
    if ($existing_servers | get -o $entry.name) == null {
      print $"<info>  - Added: ($entry.name)"
    } else {
      print $"<info>  - Updated: ($entry.name)"
    }
  }

  # Report removed servers
  for name in ($existing_servers | columns | where {|n| ($new_servers | get -o $n) == null }) {
    print $"<info>  - Removed: ($name)"
  }
}
