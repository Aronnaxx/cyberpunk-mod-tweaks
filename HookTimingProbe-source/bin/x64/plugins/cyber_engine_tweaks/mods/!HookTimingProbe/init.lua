-- HookTimingProbe v1.0 (temporary diagnostic, remove when done)
-- Finds CET mods that register Observe/ObserveBefore/ObserveAfter/Override after startup.
-- CET 1.37.1 deadlocks when a hook is registered from onUpdate while a script thread is inside an
-- already-hooked function (main-menu watchdog kills 10-13 / 10-14, New Game+ save scan + MCM/
-- nativeSettings menu hooks on the worker side). Hooks registered during onInit are safe.
-- The "!" prefix makes CET load this mod first, so the wrappers below are in _G before any other
-- mod's environment is built. Each late registration is logged once with the calling file.
-- Output: !HookTimingProbe.log in this folder + CET console.

local phase = "load"      -- load -> init (our onInit ran) -> running (first onUpdate seen)
local frames = 0
local seen = {}

local function log(msg)
  local line = "[HookTimingProbe] " .. msg
  print(line)
  spdlog.info(line)
end

local function caller()
  local ok, where = pcall(function()
    -- level 3: the mod code that called Observe/Override (1 = here, 2 = wrapper)
    for level = 3, 8 do
      local info = debug.getinfo(level, "Sl")
      if not info then break end
      local src = info.source or ""
      if not src:find("HookTimingProbe", 1, true) then
        return src .. ":" .. tostring(info.currentline)
      end
    end
    return "?"
  end)
  if ok then return where end
  return "(debug library unavailable)"
end

local function wrap(name)
  local orig = rawget(_G, name) or _G[name]
  if type(orig) ~= "function" then
    log("cannot wrap " .. name .. " (" .. type(orig) .. ")")
    return
  end
  rawset(_G, name, function(className, methodName, ...)
    if phase == "running" then
      local key = name .. " " .. tostring(className) .. "." .. tostring(methodName)
      if not seen[key] then
        seen[key] = true
        log(string.format("LATE %s after %d frames  <- %s", key, frames, caller()))
      end
    end
    return orig(className, methodName, ...)
  end)
end

for _, n in ipairs({ "Observe", "ObserveBefore", "ObserveAfter", "Override" }) do wrap(n) end
log("wrappers installed")

registerForEvent("onInit", function()
  phase = "init"
end)

registerForEvent("onUpdate", function()
  frames = frames + 1
  if phase ~= "running" then
    phase = "running"
    log("first onUpdate: hooks registered from now on are LATE")
  end
end)
