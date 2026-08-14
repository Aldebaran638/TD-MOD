# Teardown control MCP

This server is intentionally local-only. It uses MCP stdio transport and Win32
the installed `gvinput` virtual HID when available, with `SendInput` as a
fallback. It does not open a listening socket or expose a network endpoint.

From this directory, install the isolated environment and run it with:

```powershell
uv sync
uv run python server.py
```

The tools are `teardown_instances`, `teardown_status`, `teardown_observe`, `teardown_control`,
`teardown_log_read`, `teardown_telemetry_probe`, `teardown_telemetry_read`,
`teardown_damage_probe`, and `teardown_emergency_release`. The telemetry tools
use the versioned `CM2_TEST_V1` F8 `UiTextInput` bridge. The MCP temporarily
uses paste/copy to exchange text with that public game UI, then restores the
clipboard unless the user changes it during the exchange. Process/window tools
support a `target_id` so `teardown.exe` and the official local-multiplayer
`teardown_modtest.exe` Host/Client windows can be distinguished. Evidence is written to
`%LOCALAPPDATA%\TeardownAI\runs\<run-id>\` and is deliberately outside the
repository.
