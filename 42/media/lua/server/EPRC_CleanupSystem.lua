---------------------------------------------------------------
-- EPRC_CleanupSystem.lua
-- Server-side cleanup system for removing Extensive Power
-- Rework (EPR) mod data from save files.
--
-- Runs on game start (server/SP), removes all EPR world modData
-- keys, restores sandbox variables that EPR modified (ElecShut/
-- WaterShut), resets building power/water state for connected
-- buildings, and sends result notifications to clients.
--
-- Requires: PhobosLib >= 1.3.0 (Reset + Sandbox modules)
---------------------------------------------------------------

require "PhobosLib"

local EPRC = {}

---------------------------------------------------------------
-- EPR Data Keys
---------------------------------------------------------------

EPRC.WORLD_KEYS = {
    "EPR_GridData",
    "EPR_PowerController",
    "EPR_GlobalData",
    "EGO_GridData",         -- legacy key from earlier EPR version
}

-- World modData guard flag
local GUARD_FLAG = "EPRC_Cleanup_done"

---------------------------------------------------------------
-- Step 1: Sandbox Variable Restoration
---------------------------------------------------------------

--- Attempt to restore ElecShutModifier and WaterShutModifier
--- to their original values from before EPR modified them.
--- EPR stores originals in multiple locations; we try all of them.
---
--- Restores via getSandboxOptions():set() + toLua() to persist
--- to disk, matching EPR's own approach.
---
---@return boolean ok, string message
local function restoreSandboxVars()
    local restored = {}

    -- EPR stores originals in three possible locations.
    -- Field names: originalElecShut, originalWaterShut
    local sources = {
        { key = "EPR_PowerController", nested = false },
        { key = "EPR_GlobalData",      nested = false },
        { key = "EPR_GridData",        nested = true  }, -- nested under .PowerController
    }

    for _, src in ipairs(sources) do
        local data = PhobosLib.getWorldModDataValue(src.key, nil)
        if type(data) == "table" then
            local target = data
            if src.nested and type(data.PowerController) == "table" then
                target = data.PowerController
            end

            if target.originalElecShut ~= nil and not restored.elec then
                restored.elec = target.originalElecShut
            end
            if target.originalWaterShut ~= nil and not restored.water then
                restored.water = target.originalWaterShut
            end
        end

        -- Stop early if both found
        if restored.elec and restored.water then break end
    end

    -- Apply restored values
    local parts = {}
    local needFlush = false

    if restored.elec then
        pcall(function()
            SandboxVars.ElecShutModifier = restored.elec
            local options = getSandboxOptions()
            if options and options.set then
                options:set("ElecShutModifier", restored.elec)
                needFlush = true
            end
        end)
        table.insert(parts, "ElecShutModifier=" .. tostring(restored.elec))
    end

    if restored.water then
        pcall(function()
            SandboxVars.WaterShutModifier = restored.water
            local options = getSandboxOptions()
            if options and options.set then
                options:set("WaterShutModifier", restored.water)
                needFlush = true
            end
        end)
        table.insert(parts, "WaterShutModifier=" .. tostring(restored.water))
    end

    -- Persist to disk (matching EPR's own approach)
    if needFlush then
        pcall(function()
            local options = getSandboxOptions()
            if options and options.toLua then
                options:toLua()
            end
        end)
    end

    if #parts > 0 then
        return true, "Restored: " .. table.concat(parts, ", ")
    else
        return false, "No original sandbox values found in EPR data. Set ElecShutModifier/WaterShutModifier manually if needed."
    end
end

---------------------------------------------------------------
-- Step 2: Reset Connected Buildings
---------------------------------------------------------------

--- Read EPR_GridData.ConnectedBuildings and reset each building's
--- electricity and water state to false. This forces vanilla
--- mechanics to re-evaluate — buildings near working generators
--- will regain power normally.
---
---@return number count  Number of buildings reset
local function resetConnectedBuildings()
    local count = 0

    local gridData = PhobosLib.getWorldModDataValue("EPR_GridData", nil)
    if type(gridData) ~= "table" then return 0 end

    local buildings = gridData.ConnectedBuildings
    if type(buildings) ~= "table" then return 0 end

    -- ConnectedBuildings may be an array or a key-value table
    -- EPR stores records with x, y, z coordinates
    for _, record in pairs(buildings) do
        if type(record) == "table" and record.x and record.y then
            pcall(function()
                local z = record.z or 0
                local cell = getCell()
                if not cell then return end

                local square = cell:getGridSquare(record.x, record.y, z)
                if not square then return end

                local building = square:getBuilding()
                if not building then return end

                -- Reset power and water to let vanilla mechanics take over
                if building.setHasElectricity then
                    building:setHasElectricity(false)
                end
                if building.setHasWater then
                    building:setHasWater(false)
                end

                count = count + 1
            end)
        end
    end

    return count
end

---------------------------------------------------------------
-- Core Cleanup
---------------------------------------------------------------

--- Execute the full EPR cleanup operation.
---@return boolean ok, string summary
function EPRC.execute()
    local results = {}

    -- Step 1: Restore sandbox variables (if enabled)
    local restoreEnabled = PhobosLib.getSandboxVar("EPRC", "RestoreSandboxVars", true) == true
    if restoreEnabled then
        local ok, msg = restoreSandboxVars()
        table.insert(results, (ok and "[OK] " or "[INFO] ") .. msg)
    else
        table.insert(results, "[SKIP] Sandbox variable restoration disabled.")
    end

    -- Step 2: Reset connected buildings (must happen BEFORE key deletion)
    local buildingCount = resetConnectedBuildings()
    if buildingCount > 0 then
        table.insert(results, "[OK] Reset power/water state on " .. buildingCount .. " building(s).")
    else
        table.insert(results, "[INFO] No EPR-connected buildings found to reset (may not be loaded).")
    end

    -- Step 3: Strip all EPR world modData keys
    local keyCount = PhobosLib.stripWorldModDataKeys(EPRC.WORLD_KEYS)
    if keyCount > 0 then
        table.insert(results, "[OK] Removed " .. keyCount .. " EPR world modData key(s).")
    else
        table.insert(results, "[INFO] No EPR world modData keys found (already clean).")
    end

    return true, table.concat(results, "\n")
end

---------------------------------------------------------------
-- Notification Helper
---------------------------------------------------------------

---@param player any
---@param ok boolean
---@param msg string
local function notifyPlayer(player, ok, msg)
    pcall(function()
        sendServerCommand(player, "EPRC", "cleanupResult", {
            status = ok and "ok" or "fail",
            msg    = msg,
        })
    end)
end

---------------------------------------------------------------
-- World modData Guard
---------------------------------------------------------------

local function getWorldFlag(key)
    local val = nil
    pcall(function()
        val = getGameTime():getModData()[key]
    end)
    return val
end

local function setWorldFlag(key, value)
    pcall(function()
        getGameTime():getModData()[key] = value
    end)
end

---------------------------------------------------------------
-- Player Iteration
---------------------------------------------------------------

--- Get all players to notify (MP: online players, SP: player 0).
---@return table  Array of IsoGameCharacter
local function getAllPlayers()
    local players = {}
    pcall(function()
        if isClient() then return end

        local online = getOnlinePlayers()
        if online and online:size() > 0 then
            for i = 0, online:size() - 1 do
                table.insert(players, online:get(i))
            end
        else
            local p = getSpecificPlayer(0)
            if p then table.insert(players, p) end
        end
    end)
    return players
end

---------------------------------------------------------------
-- OnGameStart Hook
---------------------------------------------------------------

local function onGameStart()
    -- Only run on server or SP host, never on a dedicated client
    if isClient() then
        print("[EPRC] CleanupSystem: skipped (client context)")
        return
    end

    print("[EPRC] CleanupSystem: checking cleanup flags...")

    -- Check if ForceRerun is set — clears the guard flag
    local forceRerun = PhobosLib.getSandboxVar("EPRC", "ForceRerun", false) == true
    if forceRerun then
        print("[EPRC] CleanupSystem: ForceRerun enabled, clearing guard flag...")
        setWorldFlag(GUARD_FLAG, nil)
        PhobosLib.setSandboxVar("EPRC", "ForceRerun", false)
    end

    -- Check if cleanup should run
    local runCleanup = PhobosLib.getSandboxVar("EPRC", "RunCleanup", true) == true

    if runCleanup and not getWorldFlag(GUARD_FLAG) then
        print("[EPRC] CleanupSystem: executing EPR data cleanup...")

        local ok, summary = EPRC.execute()

        -- Notify all players
        local players = getAllPlayers()
        for _, player in ipairs(players) do
            notifyPlayer(player, ok, summary)
        end

        -- Set guard flag and reset sandbox toggle
        setWorldFlag(GUARD_FLAG, true)
        PhobosLib.setSandboxVar("EPRC", "RunCleanup", false)

        print("[EPRC] CleanupSystem: cleanup complete.")
        print("[EPRC] " .. summary)
    elseif getWorldFlag(GUARD_FLAG) then
        print("[EPRC] CleanupSystem: already executed (guard flag set). Use ForceRerun to re-execute.")
    else
        print("[EPRC] CleanupSystem: RunCleanup is disabled.")
    end

    print("[EPRC] CleanupSystem: loaded [" .. (isServer() and "server" or "local") .. "]")
end

Events.OnGameStart.Add(onGameStart)
