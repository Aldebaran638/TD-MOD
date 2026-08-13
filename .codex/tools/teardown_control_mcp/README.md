# Teardown control MCP

This server is intentionally local-only. It uses MCP stdio transport and Win32
the installed `gvinput` virtual HID when available, with `SendInput` as a
fallback. It does not open a listening socket or expose a network endpoint.

From this directory, install the isolated environment and run it with:

```powershell
uv sync
uv run python server.py
```

The tools are `teardown_status`, `teardown_observe`, `teardown_control`,
`teardown_log_read`, `teardown_telemetry_probe`, `teardown_telemetry_read`,
`teardown_damage_probe`, and `teardown_emergency_release`. The telemetry tools
use the versioned `CM2_TEST_V1` clipboard handshake and restore the clipboard
after every read unless the user changes it during the exchange. Evidence is written to
`%LOCALAPPDATA%\TeardownAI\runs\<run-id>\` and is deliberately outside the
repository.
