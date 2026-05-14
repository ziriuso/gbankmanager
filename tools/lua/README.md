# Local Lua Runner

Place a portable Lua 5.1-compatible executable at `tools/lua/lua.exe`.

The test harness loads addon files in `GBankManager.toc` order, passes one shared namespace to each chunk, and disables `dofile` during addon loading to match the WoW runtime shape.

Expected command:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```
