#!/usr/bin/env nu

# Merge MCP server configuration into workspace or user-scoped mcp.json
# This script updates MCP server configuration for VSCode
# and only writes if there are actual changes.
def main [
  --mcp-config: string # JSON string containing MCP configuration
  --scope: string = "user" # Scope: "user" or "workspace"
]: nothing -> nothing {
  let json_path = if $scope == "workspace" {
    $env.PWD | path join '.vscode' 'mcp.json'
  } else {
    $env.HOME | path join '.config' 'Code' 'User' 'mcp.json'
  }

  ensure-config-exists $json_path

  let new_servers = $mcp_config | from json | get mcpServers
  let existing_config = open $json_path
  let existing_servers = $existing_config | get -i servers | default {}

  if (has-changes $new_servers $existing_servers) {
    update-and-report {
      json_path: $json_path
      existing_config: $existing_config
      existing_servers: $existing_servers
      new_servers: $new_servers
    }
  } else {
    print $"<notice>MCP servers already up to date in ($json_path)"
  }
}

# Ensure the configuration file and its parent directory exist
def ensure-config-exists [json_path: path]: nothing -> nothing {
  let parent_dir = $json_path | path dirname

  if not ($parent_dir | path exists) {
    mkdir $parent_dir
    print $"<info>Created directory ($parent_dir)"
  }

  if not ($json_path | path exists) {
    {
      servers: {}
      inputs: []
    } | to json | save $json_path
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
    let existing = $existing_servers | get -i $name
    $existing == null or $existing != $config
  }
  | any {|x| $x }
}

# Update configuration and report changes
def update-and-report [config: record]: nothing -> nothing {
  let merged_servers = $config.existing_servers | merge $config.new_servers

  $config.existing_config
  | upsert servers $merged_servers
  | to json
  | save --force $config.json_path

  print $"<info>Updated MCP servers in ($config.json_path)"

  report-changes $config.existing_servers $config.new_servers
}

# Report what was added or updated
def report-changes [
  existing_servers: record
  new_servers: record
]: nothing -> nothing {
  $new_servers
  | items {|name _config|
    if ($existing_servers | get -i $name) == null {
      print $"<info>  - Added: ($name)"
    } else {
      print $"<info>  - Updated: ($name)"
    }
  }
}
