#!/usr/bin/env python3
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: make-release.py <Venari.lua> <VenariLocale.lua>")

    lua_path = Path(sys.argv[1])
    addon_dir = lua_path.parent
    locale_path = Path(sys.argv[2])
    toc_path = addon_dir / "Venari.toc"
    debug_path = addon_dir / "VenariDebug.lua"

    if debug_path.exists():
      debug_path.unlink()

    toc = toc_path.read_text()
    toc = toc.replace("VenariDebug.lua\n", "")
    toc_path.write_text(toc)

    locale = locale_path.read_text()
    locale = locale.replace("loaded. Commands: /venari config, /venari debug on, /venari trace on", "loaded. Commands: /venari config")
    locale = locale.replace("commands: /venari config, /venari foodlog, /venari debug on/off, /venari trace on/off/clear/status", "commands: /venari config, /venari foodlog")
    locale = locale.replace("已加载。命令：/venari config, /venari debug on, /venari trace on", "已加载。命令：/venari config")
    locale = locale.replace("命令：/venari config, /venari foodlog, /venari debug on/off, /venari trace on/off/clear/status", "命令：/venari config, /venari foodlog")
    locale_path.write_text(locale)


if __name__ == "__main__":
    main()
