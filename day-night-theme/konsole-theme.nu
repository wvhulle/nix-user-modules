# Switch Konsole profile for all running instances
export def main [
  profile_name?: string
] {
  if ($profile_name | is-empty) {
    print "Usage: konsole-theme-nu <profile>"
    print "Available commands:"
    print "  list-konsole-profiles"
    print "  get-konsole-profile"
  } else {
    set-konsole-profile $profile_name
  }
}

export def set-konsole-profile [
  profile_name: string
] {
  print $"Switching Konsole to profile: ($profile_name)"

  try {
    let pids = (pidof konsole | lines | last | str trim | split words | into int)

    if ($pids | is-empty) {
      print "No Konsole processes found"
      return
    }

    $pids | each {|pid| set-profile-for-process $pid $profile_name } | ignore
  } catch {
    print "Error: Failed to get Konsole process IDs"
  }
}

# Set profile for a specific Konsole process
def set-profile-for-process [pid: int profile_name: string] {
  let service = $"org.kde.konsole-($pid)"

  try {
    let windows = get-konsole-windows $service
    $windows | each {|window_id| set-profile-for-window $service $window_id --profile-name $profile_name --pid $pid }
  } catch {
    print $"Failed to discover windows for PID ($pid)"
  }
}

# Get window IDs for a Konsole service
def get-konsole-windows [service: string]: nothing -> list<int> {
  qdbus $service | lines | where ($it | str starts-with "/Windows/") | each {|line|
    $line | str replace "/Windows/" "" | into int
  }
}

# Set profile for a specific window
def set-profile-for-window [service: string window_id: int --profile-name: string --pid: int] {
  try {
    qdbus $service $"/Windows/($window_id)" setDefaultProfile $profile_name
    print $"Set default profile for window ($window_id) of PID ($pid)"
  } catch {
    print $"Failed to set default profile for window ($window_id) of PID ($pid)"
  }

  try {
    let sessions = get-window-sessions $service $window_id
    $sessions | each {|session| set-profile-for-session $service $session --profile-name $profile_name --window-id $window_id --pid $pid }
  } catch {
    print $"Failed to get sessions for window ($window_id) of PID ($pid)"
  }
}

# Get session IDs for a window
def get-window-sessions [service: string window_id: int]: nothing -> list<int> {
  qdbus $service $"/Windows/($window_id)" sessionList
  | lines
  | each {|line| $line | str trim | into int }
}

# Set profile for a specific session
def set-profile-for-session [service: string session: int --profile-name: string --window-id: int --pid: int] {
  try {
    qdbus $service $"/Sessions/($session)" setProfile $profile_name
    print $"Set profile for session ($session) in window ($window_id) of PID ($pid)"
  } catch {
    print $"Failed to set profile for session ($session) in window ($window_id) of PID ($pid)"
  }
}

# List available Konsole profiles
export def list-konsole-profiles [] {
  try {
    let profile_dirs = [
      "~/.local/share/konsole"
      "~/.config/konsole"
      "/usr/share/konsole"
    ]

    let profiles = $profile_dirs | each {|dir| get-profiles-from-dir $dir } | flatten | uniq | sort

    if ($profiles | is-empty) {
      print "No Konsole profiles found"
      return []
    }

    $profiles
  } catch {
    print "Error: Failed to list profiles"
    []
  }
}

# Get profiles from a specific directory
def get-profiles-from-dir [dir: path]: nothing -> list<string> {
  try {
    glob ($dir | path expand | path join "*.profile") | each {|file|
      $file | path basename | str replace ".profile" ""
    }
  } catch {
    []
  }
}

# Get current Konsole profile (from first process)
export def get-konsole-profile [] {
  try {
    let pids = (pidof konsole | lines | last | str trim | split words | into int)

    if ($pids | is-empty) {
      print "No Konsole processes found"
      return null
    }

    let pid = ($pids | first)
    let service = $"org.kde.konsole-($pid)"

    try {
      let windows = get-konsole-windows $service

      if ($windows | is-empty) {
        print "No windows found for this Konsole process"
        return null
      }

      let first_window = ($windows | first)
      qdbus $service $"/Windows/($first_window)" defaultProfile | str trim
    } catch {
      print "Failed to get current profile"
      null
    }
  } catch {
    print "Error: Failed to get Konsole process IDs"
    null
  }
}
