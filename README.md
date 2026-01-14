# OWM
A minimal window manager extending the native MacOS window management with:
- layouts
- window movement hotkeys (MacOS also has some)

## Status
Works but is not round.

## Config
Is a juston file expected at `~/.config/owm/config.json`.

### Actions
Actions are performed once a key combination is pressed on the currently (keyboard-)focused window.
The following actions are supported:
- *right*           -> tile right
- *rightMonitor*    -> move to right monitor maximized 
- *left*            -> tile left
- *leftMonitor*     -> move to left monitor maximized
- *up*              -> tile up
- *down*            -> tile down
- *maximize*        -> maximize window

Example:
```json
{
  "actions": [
    {
      "when": ["CapsLock", "L"],
      "do": "right"
    }
  ]
}
```

### Layouts
Layouts allow quick arrangement of windows using key combinations. Where the following layouts
are supported:
- *maximize*    -> make the last focused window of the specified application maximize on the current screen
- *split*       -> split the last focused windows of of the applications on the current screen

Example:
```json
{
  "layouts": [
    {
      "when": ["CapsLock", "1"],
      "do": {"maximize": "Ghostty"}
    },
    {
      "when": ["CapsLock", "3"],
      "do": {"split": {"left": "Ghostty", "right": "Safari"}}
    }
  ]
}
```

### Buttons
- A-Z
- 0-9
- Command, Shift, Option, Shift
- Space, Tab, Return, Escape, Delete
- CapsLock (*see: The CapsLock Problem*)

## Building & Installing
```sh
# 1. build the binary and the app
mise run install
# 2. GOTO: settings > privacy & security > accessibility > add app (~/Applications/owm.app)
# 3. install the plist entry
mise run install-svc
```

### Encounted Hurdles
#### The Workspace Problem
MacOS Spaces are kind of a *black box*.
- managing them requires a private and undocumented APIs
- querying windows on non-visible workspaces is unreliable
- all fullscreen apps are always placed in their own workspace (therefore prefer maximized windows)
- window managers like AeroSpace are also trying to avoid workspaces

#### The CapsLock Problem
Managing the Caps Lock key proved to be one of the more significant
hurdles during development. Unlike standard keys, Caps Lock carries
a persistent internal state that must be handled differently:

##### Core Graphics Event Taps
While standard for intercepting input, Event Taps fail here.
Even if an event is blocked or modified, the system registers
the Caps Lock state change internally before the tap can intervene.

##### HID Manager (Passive)
One can attempted to monitor raw HID events to detect press/release cycles
(which Event Taps don't expose for Caps Lock). By programmatically firing
a second "press" to revert the state. This however can lead to 
race conditions with other system inputs.

##### HID Manager (Exclusive)
Taking exclusive control of the keyboard device solves the state issue but
is far too intrusive for a window manager, as it disrupts other system-level
input handling.

##### Solution
The most robust approach involves using the hidutil
method to remap Caps Lock to an unassigned key (like F20) at the kernel
level. This ensures the key behaves like any other standard key.
While this does effectively "remove" the global Caps Lock function,
it allows for easier management of the Caps Lock state.

> **using Caps Lock in any key combination will trigger the remapping automatically**
