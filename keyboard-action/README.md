# Keyboard Action Module

A NixOS user module for binding custom actions to keyboard shortcuts at the input event level.

## Prerequisites

Since this is a home-manager module, it cannot modify system-level group memberships. You must add users to the `input` group in your NixOS system configuration:

```nix
# In your machine-specific or system configuration:
users.users.youruser.extraGroups = [ "input" ];
```

After adding the group, you must **log out and log back in** for the group membership to take effect.

## Usage

### Basic Configuration

```nix
{
  programs.keyboard-action = {
    enable = true;
    
    actions = {
      my-shortcut = {
        keyDescription = "Super+Alt+T";
        
        keys = [
          {
            name = "super";
            eventName = "KEY_LEFTMETA";
            code = 125;
          }
          {
            name = "alt";
            eventName = "KEY_LEFTALT";
            code = 56;
          }
          {
            name = "t";
            eventName = "KEY_T";
            code = 20;
          }
        ];
        
        triggerKey = {
          name = "t";
          eventName = "KEY_T";
        };
        
        action = "${pkgs.kitty}/bin/kitty";
      };
    };
  };
}
```

### Finding Key Codes

Use `evtest` to find the event names and codes for your keys:

```bash
sudo evtest /dev/input/by-path/*kbd
# Press the key you want to use
# Look for lines like: "Event: ... EV_KEY, code 20 (KEY_T), value 1"
```

The output shows:

- `KEY_T` - this is the `eventName`
- `20` - this is the `code`

## Troubleshooting

### Service Status

Check if the service is running:

```bash
systemctl --user --no-pager status keyboard-action-*
```

### Test Keyboard Device

Verify keyboard events are being captured:

```bash
sudo evtest /dev/input/by-path/*kbd
```
