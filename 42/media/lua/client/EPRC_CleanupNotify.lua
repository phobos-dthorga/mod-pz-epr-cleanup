---------------------------------------------------------------
-- EPRC_CleanupNotify.lua
-- Client-side listener for EPR cleanup result notifications.
-- Always shows a modal dialog since this is a one-shot utility
-- and the user needs clear confirmation of what happened.
--
-- Success: green-header modal with cleanup summary.
-- Failure: red-header modal with error details.
---------------------------------------------------------------

local EPRC_Notify = {}

---------------------------------------------------------------
-- Modal Dialog
---------------------------------------------------------------

--- Show a modal dialog with cleanup results.
--- Cannot be missed at any game speed.
---@param msg string
---@param isOk boolean
local function showModal(msg, isOk)
    pcall(function()
        local header
        if isOk then
            header = " <SIZE:medium> <RGB:0.3,0.8,0.3> EPR Cleanup Complete <RGB:1,1,1> "
        else
            header = " <SIZE:medium> <RGB:1,0.3,0.3> EPR Cleanup Warning <RGB:1,1,1> "
        end

        -- Replace newlines with <LINE> tags for ISModalRichText
        local body = string.gsub(msg, "\n", " <LINE> ")

        local text = header
            .. " <LINE> <LINE> <SIZE:small> "
            .. body
            .. " <LINE> <LINE> "
            .. " <RGB:0.6,0.6,0.6> You may now unsubscribe from PhobosEPRCleanup if you no longer need it. "
            .. "Check the console log (press ~ or F3) for full details. <RGB:1,1,1> "

        local modal = ISModalRichText:new(
            getCore():getScreenWidth() / 2 - 280,
            getCore():getScreenHeight() / 2 - 150,
            560,
            300,
            text,
            true  -- OK button only
        )
        modal:initialise()
        modal:addToUIManager()
    end)

    local prefix = isOk and "SUCCESS" or "WARNING"
    print("[EPRC] CleanupNotify: " .. prefix .. " -> " .. msg)
end

---------------------------------------------------------------
-- HaloText (supplemental)
---------------------------------------------------------------

--- Show a green on-screen halo text as a quick visual indicator.
---@param player any
---@param msg string
local function showHaloText(player, msg)
    pcall(function()
        if HaloTextHelper and HaloTextHelper.addTextWithArrow then
            HaloTextHelper.addTextWithArrow(player, true, msg)
        elseif HaloTextHelper and HaloTextHelper.addText then
            HaloTextHelper.addText(player, msg, HaloTextHelper.getColorGreen())
        end
    end)
end

---------------------------------------------------------------
-- Server Command Listener
---------------------------------------------------------------

local function onServerCommand(module, command, args)
    if module ~= "EPRC" or command ~= "cleanupResult" then return end
    if not args then return end

    local msg = args.msg or "EPR cleanup operation completed."
    local isOk = (args.status == "ok")

    -- Always show modal for this one-shot utility
    showModal(msg, isOk)

    -- Also show halo text if player exists and it was successful
    if isOk then
        local player = nil
        pcall(function()
            player = getSpecificPlayer(0)
        end)
        if player then
            showHaloText(player, "[EPRC] EPR data cleaned!")
        end
    end
end

Events.OnServerCommand.Add(onServerCommand)

print("[EPRC] CleanupNotify: loaded [client]")
