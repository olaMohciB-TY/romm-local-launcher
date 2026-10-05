# romm-local-launcher

Experimental local launcher for RomM. Opens a game from a `romm://play/<romId>` link
using the emulator configured for that platform on your PC.

Status: early prototype, Windows 11 only, untested by others. No release date.

## How it works
1. Windows has a registered `romm://` protocol (see `register.reg`).
2. `handler.ps1` receives the link, asks the RomM API for the game's platform and file name,
   reads `config.json`, and starts the emulator with the ROM path.

## Setup (Windows)
1. Copy `config.ejemplo.json` to `config.json` and edit it.
2. Set the user environment variables `ROMM_USER` and `ROMM_PASS`.
3. Edit the path in `register.reg` and double-click it.
4. Test with Win+R: `romm://play/<romId>`.

## Notes
- Do not commit `config.json` or credentials.
- Parts of this project were written with AI assistance.