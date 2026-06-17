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

Both build scripts accept an optional version key. TBC is the default:

```sh
scripts/build-release.sh tbc-anniversary-cn
scripts/build-debug.sh tbc-anniversary-cn
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

## Version Ports

Client-specific behavior is routed through `VenariPort`, which is loaded before
the main addon file. Build scripts copy exactly one implementation into the
addon root:

```text
ports/tbc-anniversary-cn/VenariPort.lua
ports/mop-classic-cn/VenariPort.lua
```

The shared HUD code can call stable port hooks without packaging every client
branch into the final addon. Current boundary:

- `VenariPort.spells.apply(spellBook)`: lets each client target override spell
  IDs, ranks, and icons before the HUD initializes.

MoP is scaffolded as a port target but remains disabled in the package manager
until hunter mechanics, spell IDs, pet happiness, and food rules are validated.
