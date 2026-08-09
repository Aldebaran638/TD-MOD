---@diagnostic disable: undefined-global

-- Kept as a lifecycle shim for existing bootstrap order.  Beam and impact work
-- lives in bounded specialised modules.
client = client or {}
function client.perditionLaunchFxInit() end
function client.perditionLaunchFxTick(_) end
