VenariDebug = VenariDebug or {}

local traceDefaults = {
  enabled = false,
  maxRecords = 400,
  records = {},
}

local function traceDb()
  VenariDB = VenariDB or {}
  if type(VenariDB.trace) ~= "table" then
    VenariDB.trace = {}
  end
  local trace = VenariDB.trace
  if trace.enabled ~= true then
    trace.enabled = false
  end
  if type(trace.maxRecords) ~= "number" or trace.maxRecords < 50 then
    trace.maxRecords = traceDefaults.maxRecords
  end
  if trace.maxRecords > 1000 then
    trace.maxRecords = 1000
  end
  if type(trace.records) ~= "table" then
    trace.records = {}
  end
  return trace
end

function VenariDebug.RecordCount()
  local trace = traceDb()
  return type(trace.records) == "table" and #trace.records or 0
end

function VenariDebug.TraceAutoShot(state, readAutoShotCooldown, kind, data)
  local cfg = traceDb()
  if not cfg.enabled then
    return
  end

  local records = cfg.records
  local now = GetTime and GetTime() or 0
  local timerStart = state.autoShotTimerStart
  local timerDuration = state.autoShotTimerDuration
  local remain, progress
  if state.autoRepeat and timerStart and timerDuration and timerDuration > 0 then
    local elapsed = now - timerStart
    remain = math.max(0, timerDuration - elapsed)
    progress = math.min(1, math.max(0, elapsed / timerDuration))
  end

  local cdStart, cdDuration, cdEnabled
  if data and data.cdStart ~= nil then
    cdStart = data.cdStart
    cdDuration = data.cdDuration
    cdEnabled = data.cdEnabled
  elseif type(readAutoShotCooldown) == "function" then
    cdStart, cdDuration, cdEnabled = readAutoShotCooldown()
  end

  local record = {
    t = now,
    kind = kind,
    event = state.lastEvent,
    auto = state.autoRepeat,
    rangedSpeed = state.rangedSpeed,
    lastRangedSpeed = state.lastRangedSpeed,
    lastAutoShot = state.lastAutoShot,
    lastAutoShotSource = state.lastAutoShotSource,
    lastAutoRepeatStart = state.lastAutoRepeatStart,
    cdStart = cdStart,
    cdDuration = cdDuration,
    cdEnabled = cdEnabled,
    timerStart = timerStart,
    timerDuration = timerDuration,
    timerSource = state.autoShotTimerSource,
    pending = state.autoShotPending,
    armed = state.autoShotArmed,
    remain = remain,
    progress = progress,
    count = state.autoShotCount,
  }

  if type(data) == "table" then
    for key, value in pairs(data) do
      if type(value) ~= "function" and type(value) ~= "thread" and type(value) ~= "userdata" then
        record[key] = value
      end
    end
  end

  records[#records + 1] = record
  local maxRecords = cfg.maxRecords or traceDefaults.maxRecords
  while #records > maxRecords do
    table.remove(records, 1)
  end
end

function VenariDebug.TraceAutoShotState(state, readAutoShotCooldown, kind, data)
  if not traceDb().enabled then
    return
  end
  local key = table.concat({
    tostring(kind),
    tostring(state.autoShotTimerSource),
    tostring(state.autoShotPending),
    tostring(state.autoShotArmed),
    tostring(state.autoShotTimerStart),
    tostring(state.autoShotTimerDuration),
    tostring(state.autoShotCount),
  }, "|")
  if key == state.autoShotTraceLastKey then
    return
  end
  state.autoShotTraceLastKey = key
  VenariDebug.TraceAutoShot(state, readAutoShotCooldown, kind, data)
end

function VenariDebug.HandleCommand(input, context)
  if input == "debug on" then
    local cfg = context.db()
    cfg.debug = true
    context.refresh("debug")
    context.printMsg(context.L("msg.debugEnabled"))
    return true
  end

  if input == "debug off" then
    local cfg = context.db()
    cfg.debug = false
    context.refresh("debug")
    context.printMsg(context.L("msg.debugDisabled"))
    return true
  end

  if input == "debug" then
    context.printMsg(context.L("msg.debugUsage"))
    return true
  end

  if input == "trace on" then
    local trace = traceDb()
    trace.enabled = true
    trace.records = {}
    trace.startedAt = time and time() or nil
    trace.note = "temporary auto shot trace; remove when timer algorithm is stable"
    context.state.autoShotTraceLastKey = nil
    VenariDebug.TraceAutoShot(context.state, context.readAutoShotCooldown, "trace-on")
    context.printMsg(context.L("msg.traceEnabled"))
    return true
  end

  if input == "trace off" then
    VenariDebug.TraceAutoShot(context.state, context.readAutoShotCooldown, "trace-off")
    local trace = traceDb()
    trace.enabled = false
    trace.stoppedAt = time and time() or nil
    context.printMsg((context.L("msg.traceDisabled")):format(VenariDebug.RecordCount()))
    return true
  end

  if input == "trace clear" then
    local trace = traceDb()
    trace.records = {}
    context.state.autoShotTraceLastKey = nil
    context.printMsg(context.L("msg.traceCleared"))
    return true
  end

  if input == "trace" or input == "trace status" then
    local trace = traceDb()
    context.printMsg((context.L("msg.traceStatus")):format(tostring(trace.enabled), VenariDebug.RecordCount(), trace.maxRecords or traceDefaults.maxRecords))
    return true
  end

  return false
end
