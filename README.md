# Venari WoW Plugin

Venari is a hunter HUD addon for WoW Classic/TBC Anniversary.

## Build

Debug build, including temporary debug and trace commands:

```sh
scripts/build-debug.sh
```

Release build, excluding the temporary debug and trace commands:

```sh
scripts/build-release.sh
```

Build outputs are written to:

- `dist/debug/Venari`
- `dist/release/Venari`
- `dist/Venari-debug.zip`
- `dist/Venari-release.zip`

## Temporary Diagnostics

The source build currently includes temporary diagnostics while the auto-shot
timer model is being stabilized:

- `/venari debug on|off`
- `/venari trace on|off|clear|status`

Release builds remove those command paths and force debug/trace storage off.
These diagnostics are intended to be deleted from source after the timer model
is confirmed stable.
