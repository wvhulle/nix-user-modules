#!/usr/bin/env nu

# Create ActivityWatch config directory and copy config file
export def main [
  config_file: string
] {
  let config_dir = $"($env.HOME)/.config/activitywatch/aw-server-rust"
  ^mkdir -p $config_dir
  ^rm -f $"($config_dir)/config.toml"
  ^cp $config_file $"($config_dir)/config.toml"
}
