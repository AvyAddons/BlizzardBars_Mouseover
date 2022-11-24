MouseOverBars = LibStub("AceAddon-3.0"):NewAddon("MouseOverBars")

-- Retrieve addon folder name, and our local, private namespace.
---@type string, table
local addonName, addon = ...

-- Fetch the localization table
---@type table<string, string>
local L = addon.L

--[==[@debug@
_G[addonName] = addon
--@end-debug@]==]

-- Lua API
-----------------------------------------------------------
-- Up-value any lua functions used here.
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs
local string_gsub = string.gsub
local string_find = string.find
local string_split = string.split

-- WoW API
-----------------------------------------------------------
-- Up-value any WoW functions used here.
local _G = _G
---@type table<string, function>
local SlashCmdList = _G["SlashCmdList"]
local GetBuildInfo = _G.GetBuildInfo
local GetAddOnInfo = _G.GetAddOnInfo
local GetNumAddOns = _G.GetNumAddOns
local GetAddOnEnableState = _G.GetAddOnEnableState
local GetTime = _G.GetTime
local C_TimerAfter = _G.C_Timer.After
---@type Frame
local QuickKeybindFrame = _G["QuickKeybindFrame"]
---@type Frame
local EditModeManagerFrame = _G["EditModeManagerFrame"]
---@type Frame
local SpellFlyout = _G["SpellFlyout"]

-- Constants
-----------------------------------------------------------
local MAIN_BAR = "MainMenuBar"
local PET_BAR = "PetActionBar"
local PET_ACTION_BUTTON = "PetActionButton"

-- Your default settings.
-----------------------------------------------------------
-- Note that anything changed will be saved to disk when you reload the user
-- interface, or exit the game, and those saved changes will override your
-- defaults here.
-- * You should access saved settings by using `db[key]`
-- * Don't put frame handles or other widget references in here,
--   just strings, numbers, and booleans. Tables also work.

-- Utility Functions
-----------------------------------------------------------
-- Add utility functions like time formatting and similar here.

--- Fires a callback after `delay` seconds has passed.
---@param fn function Void callback
---@param delay number Delay in seconds
---@param every number repeat Every in seconds
---@return table timer The timer table
function addon:Timer(fn, delay, every)
    -- C_TimerAfter doesn't allow anything below
    if delay < 0.01 then
        delay = 0.01
    end

    local timer = {
        delay = delay,
        fn = fn,
        ends = GetTime() + delay,
        cancelled = false
    }

    timer.callback = function()
        if not timer.cancelled then
            timer.fn()
            if every ~= nil then
                C_TimerAfter(every, timer.callback)
            end
        end
    end

    C_TimerAfter(delay, timer.callback)
    return timer
end

---Cancel a timer by the bar name
---@param bar_name string
function addon:CancelTimer(bar_name)
    local timer = self.timers[bar_name]
    if timer then
        timer.cancelled = true
    end
end

function addon:CancelAllTimers()
    for _, timer in pairs(self.timers) do
        timer.cancelled = true
    end
end

local function indexOf(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end
    return nil
end

function addon:GetFlyoutParent()
    if (SpellFlyout:IsShown()) then
        local parent = SpellFlyout:GetParent()
        local parent_name = parent:GetName() or ""
        if (string_find(parent_name, "([Bb]utton)%d")) then
            local index = indexOf(self.button_names, string_gsub(parent_name, "%d", ""))
            if (index) then
                return self.bar_names[index]
            end
        end
    end
    return nil
end

-- Addon API
-----------------------------------------------------------

--- Saves table to addon database
--- Remarks; it merges existing data with updated data and updates addon.db
---@param : any
function addon:SaveToDB(values)
    local currentValues = _G[addonName .. "_DB"]
    if currentValues == nil then
        currentValues = {}
    end
    for k, v in pairs(values) do
        currentValues[k] = v
    end
    _G[addonName .. "_DB"] = currentValues
    self.db = currentValues
end

--- Securely hooks into a frame's OnEnter and OnLeave to show/hide.
---@param frame Frame Base frame on which to hook
---@param alpha_target Frame Frame whose alpha should change
---@param bar_name string Name of the base frame
function addon:SecureHook(frame, alpha_target, bar_name)
    -- because references need to be resolved on runtime, we can't declare the bypasses here
    -- instead we can use a function or copypaste stuff inside the callbacks
    local function CheckBypass()
        -- if we're dragonriding and this is the main bar, bypass the function
        local dragonridingBypass = (self.dragonriding and bar_name == MAIN_BAR)
        -- ad-hoc bypass of any given bar
        local adHocBypass = (self.bypass == bar_name or addon.optionValues[bar_name] == false)

        return not (dragonridingBypass or adHocBypass)
    end

    frame:HookScript("OnEnter", function()
        if (addon.enabled and CheckBypass()) then
            addon:CancelTimer(bar_name)
            addon.timers[bar_name] = addon:FadeInBarTimer(alpha_target, bar_name)
        end
    end)

    frame:HookScript("OnLeave", function()
        if (addon.enabled and CheckBypass()) then
            addon:CancelTimer(bar_name)
            addon.timers[bar_name] = addon:FadeOutBarTimer(alpha_target, bar_name)
        end
    end)
end

function addon:FadeInBarTimer(alpha_target, bar_name)
    local alpha = addon.fades[bar_name]
    if alpha == nil then
        alpha = addon.optionValues["AlphaMin"]
        addon.fades[bar_name] = alpha
    end
    local timer = addon:Timer(function()
        alpha = alpha + addon.computedOptionValues["FadeInAlphaStep"]
        if alpha >= addon.optionValues["AlphaMax"] then
            addon:CancelTimer(bar_name)
            alpha = addon.optionValues["AlphaMax"]
        end
        addon.fades[bar_name] = alpha
        alpha_target:SetAlpha(alpha)
    end, (addon.optionValues["FadeInDelay"] or 0), addon.optionValues["MaxRefreshRate"])
    return timer
end

function addon:FadeOutBarTimer(alpha_target, bar_name)
    local alpha = addon.fades[bar_name]
    if alpha == nil then
        alpha = addon.optionValues["AlphaMax"]
        addon.fades[bar_name] = alpha
    end
    local timer = addon:Timer(function()
        alpha = alpha - addon.computedOptionValues["FadeOutAlphaStep"]
        if alpha <= addon.optionValues["AlphaMin"] then
            addon:CancelTimer(bar_name)
            alpha = addon.optionValues["AlphaMin"]
        end
        addon.fades[bar_name] = alpha
        alpha_target:SetAlpha(alpha)
    end, (addon.optionValues["FadeOutDelay"] or 0), addon.optionValues["MaxRefreshRate"])
    return timer
end

---Securely hook a bar and its buttons
---@param bar Frame
---@param bar_name string
function addon:HookBar(bar, bar_name)
    -- Ignore some bars according to configuration to apply min alpha
    if (addon.optionValues[bar_name]) then
        bar:SetAlpha(addon.optionValues["AlphaMin"])
    end
    -- this only hooks the bar frame, buttons are ignored here
    self:SecureHook(bar, bar, bar_name)
    -- so we have to hook buttons individually
    for _, button in pairs(self.buttons[bar_name]) do
        self:SecureHook(button, bar, bar_name)
        self:SetBling(button.cooldown, false)
    end
end

--- Hook all bars
function addon:HookBars()
    self:ResumeCallbacks()
    -- these secure hooks are automatically de-hook on reload/relog, we can ignore OnDisable
    for bar_name, bar in pairs(self.bars) do
        self:HookBar(bar, bar_name)
    end
end

---Sets the bling flag on a cooldown
---@param cooldown Cooldown
---@param flag boolean
function addon:SetBling(cooldown, flag)
    if not cooldown then
        return
    end
    cooldown:SetDrawBling(flag)
end

---Sets the bling for each button in a bar
---@param bar_name string
---@param flag boolean
function addon:SetBlingRender(bar_name, flag)
    if not self.buttons[bar_name] then
        return
    end
    for _, button in ipairs(self.buttons[bar_name]) do
        self:SetBling(button.cooldown, flag)
    end
end

--- Resumes callbacks
function addon:ResumeCallbacks()
    self.enabled = true
end

--- Pauses callbacks without actually unhooking them
function addon:PauseCallbacks()
    self.enabled = false
end

--- Show all bars
function addon:ShowBars()
    self:CancelAllTimers()
    self:PauseCallbacks()
    for bar_name, bar in pairs(self.bars) do
        bar:SetAlpha(1)
        self:SetBlingRender(bar_name, true)
    end
end

--- Hide all bars
function addon:HideBars()
    self:ResumeCallbacks()
    for bar_name, bar in pairs(self.bars) do
        addon:ApplyOnBar(bar, bar_name, nil)
        self:SetBlingRender(bar_name, false)
    end
end

--- Toggle bar visibility and (un)register grid events
function addon:ToggleBars()
    if addon.enabled then
        self:ShowBars()
        self:UnregisterAllEvents()
    else
        self:HideBars()
        self:RegisterEvent("ACTIONBAR_SHOWGRID")
        self:RegisterEvent("ACTIONBAR_HIDEGRID")
        self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    end
end

--- Show main vehicle bar
function addon:Dragonriding()
    if (not self.enabled) then
        return
    end
    if (IsMounted() and HasBonusActionBar()) then
        -- we're dragonriding
        self.dragonriding = true
        -- show main bar
        self.bars[MAIN_BAR]:SetAlpha(1)
    elseif (not IsMounted() and self.dragonriding) then
        -- if we were dragonriding and stopped, hide everything again
        self.dragonriding = false
        self.bars[MAIN_BAR]:SetAlpha(0)
    end
end

function addon:HandleFlyoutShow()
    -- ignore when bypass enabled
    if (not self.enabled) then
        return
    end
    -- this returns nil if the parent isn't one of the bars we're hiding
    self.bypass = self:GetFlyoutParent()
    self:CancelTimer(self.bypass)
    self.bars[self.bypass]:SetAlpha(1)
end

function addon:HandleFlyoutHide()
    -- ignore when bypass enabled
    if (not self.enabled) then
        return
    end
    local prev_bypass = self.bypass
    if (prev_bypass) then
        self.bypass = nil
        addon.timers[prev_bypass] = addon:Timer(function()
            self.bars[prev_bypass]:SetAlpha(0)
        end, 1.2)
    end
end

---Handles the pet bar chat command
---@param flag boolean|string
function addon:PetBarHandler(flag)
    if (type(flag) == string) then
        self.db["pet_bar_ignore"] = not self.db["pet_bar_ignore"]
    else
        self.db["pet_bar_ignore"] = flag
    end
    if (self.db["pet_bar_ignore"]) then
        self:Print("Pet bar mouseover disabled.\nDisabling mouseover requires a /reload before you can see changes!")
    else
        self:Print("Pet bar mouseover enabled.")
        -- prevent multiple toggles from stacking hooks
        if (not self.bars[PET_BAR]) then
            self.bars[PET_BAR] = _G[PET_BAR]
            self.buttons[PET_BAR] = {}
            for i = 1, 10 do
                self.buttons[PET_BAR][i] = _G[PET_ACTION_BUTTON .. i]
            end
            -- handles adding the callbacks, setting alpha, and disabling cooldown bling
            self:HookBar(_G[PET_BAR], PET_BAR)
        end
    end
end

-- Addon Tables
-----------------------------------------------------------
addon.timers = {}
addon.fades = {}
addon.bars = {}
addon.buttons = {}
addon.bar_names = {MAIN_BAR, "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5",
                   "MultiBar6", "MultiBar7", "StanceBar"}
addon.button_names = {"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
                      "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button", "StanceButton"}

-- these are bypasses and control hover callbacks
--- Global hover bypass
addon.enabled = true
--- Dragonriding hover bypass
addon.dragonriding = false
--- Generic bypass, currently in use for flyouts
---@type string|nil
addon.bypass = nil
--- Configuration panel
addon.configOptions = {
    name = "MouseOverBars",
    handler = MouseOverBars,
    type = "group",
    width = "full",
    get = "GetValue",
    set = "SetNumberValue",
    args = {
        ActionBars = {
            order = 1,
            name = "Action Bars",
            type = "header"
        },
        MainMenuBar = {
            order = 2,
            name = "Action Bar 1",
            type = "toggle",
            desc = "Activate Mouseover on Action Bar 1",
            width = 0.9,
            set = "SetBoolValue"
        },
        MultiBarBottomLeft = {
            order = 2,
            name = "Action Bar 2",
            type = "toggle",
            desc = "Activate Mouseover on Action Bar 2",
            width = 0.9,
            set = "SetBoolValue"
        },
        MultiBarBottomRight = {
            order = 2,
            name = "Action Bar 3",
            type = "toggle",
            desc = "Activate Mouseover on Action Bar 3",
            width = 0.9,
            set = "SetBoolValue"
        },
        MultiBarRight = {
            order = 2,
            name = "Action Bar 4",
            type = "toggle",
            desc = "Activate Mouseover on Action Bar 4",
            width = 0.9,
            set = "SetBoolValue"
        },
        MultiBarLeft = {
            order = 2,
            name = "Action Bar 5",
            type = "toggle",
            desc = "Activate Mouseover on Action Bar 5",
            width = 0.9,
            set = "SetBoolValue"
        },
        MultiBar5 = {
            order = 2,
            name = "Action Bar 6",
            type = "toggle",
            desc = "Activate Mouseover on Action Bar 6",
            width = 0.9,
            set = "SetBoolValue"
        },
        MultiBar6 = {
            order = 2,
            name = "Action Bar 7",
            type = "toggle",
            desc = "Activate Mouseover on Action Bar 7",
            width = 0.9,
            set = "SetBoolValue"
        },
        MultiBar7 = {
            order = 2,
            name = "Action Bar 8",
            type = "toggle",
            desc = "Activate Mouseover on Action Bar 8",
            width = 0.9,
            set = "SetBoolValue"
        },
        FadeInTime = {
            order = 3,
            name = "Fade in Times",
            type = "header"
        },
        FadeInDelay = {
            order = 4,
            name = "Fade in Delay",
            desc = "Time before fade in start",
            type = "range",
            min = 0,
            max = 3,
            step = 0.01,
            width = 1.8
        },
        FadeInDuration = {
            order = 4,
            name = "Fade in Duration",
            desc = "Time to reach max Alpha",
            type = "range",
            min = 0,
            max = 3,
            step = 0.01,
            width = 1.8
        },
        FadeOutTime = {
            order = 5,
            name = "Fade out Times",
            type = "header"
        },
        FadeOutDelay = {
            order = 6,
            name = "Fade out Delay",
            desc = "Time before fade out start",
            type = "range",
            min = 0,
            max = 3,
            step = 0.01,
            width = 1.8
        },
        FadeOutDuration = {
            order = 6,
            name = "Fade out Duration",
            desc = "Time to reach min Alpha",
            type = "range",
            min = 0,
            max = 3,
            step = 0.01,
            width = 1.8
        },
        Alpha = {
            order = 7,
            name = "Alpha",
            type = "header"
        },
        AlphaMin = {
            order = 8,
            name = "Minimum Alpha",
            desc = "Set the minimum visibility (alpha) of Action Bars",
            type = "range",
            min = 0,
            max = 1,
            step = 0.01,
            width = 1.8
        },
        AlphaMax = {
            order = 9,
            name = "Maximum Alpha",
            desc = "Set the maximum visibility (alpha) of Action Bars",
            type = "range",
            min = 0,
            max = 1,
            step = 0.01,
            width = 1.8
        }
    }
}
--- Configuration option values
addon.optionValues = {
    MainMenuBar = true,
    MultiBarBottomLeft = true,
    MultiBarBottomRight = true,
    MultiBarRight = true,
    MultiBarLeft = true,
    MultiBar5 = true,
    MultiBar6 = true,
    MultiBar7 = true,
    FadeInDelay = 0,
    FadeInDuration = 0.2,
    FadeOutDelay = 0,
    FadeOutDuration = 0.2,
    AlphaMin = 0,
    AlphaMax = 1,
    MaxRefreshRate = 0.01
}

--- Computed option values
addon.computedOptionValues = {
    FadeInAlphaStep = 0.1,
    FadeOutAlphaStep = 0.1
}

--- Compute option values
function addon:ComputeValues()
    -- TODO: check if we can use math.abs()
    local alphaRange = self.optionValues["AlphaMax"] - self.optionValues["AlphaMin"]
    self.computedOptionValues = {
        FadeInAlphaStep = alphaRange / (self.optionValues["FadeInDuration"] / self.optionValues["MaxRefreshRate"]),
        FadeOutAlphaStep = alphaRange / (self.optionValues["FadeOutDuration"] / self.optionValues["MaxRefreshRate"])
    }
end

-- Addon Core
-----------------------------------------------------------
-- Your event handler.
-- Any events you add should be handled here.
--- @param event WowEvent The name of the event that fired.
--- @param ... unknown Any payloads passed by the event handlers.
function addon:OnEvent(event, ...)
    if (event == "PLAYER_MOUNT_DISPLAY_CHANGED") then
        -- print("EVENT PLAYER_MOUNT_DISPLAY_CHANGED")
        self:Dragonriding()
    elseif (event == "ACTIONBAR_SHOWGRID") then
        self:ShowBars()
    elseif (event == "ACTIONBAR_HIDEGRID") then
        self:HideBars()
    end
end

-- Your chat command handler.
---@param editBox table|frame The editbox the command was entered into.
---@param command string The name of the slash command type in.
---@param ... string Any additional arguments passed to your command, all as strings.
function addon:OnChatCommand(editBox, command, ...)
    local arg1, arg2 = ...
    if (arg1 == "toggle") then
        self:ToggleBars()
    elseif (arg1 == "pet") then
        local flag = "toggle"
        if (arg2 and (arg2 == "enabled" or arg2 == "on" or arg2 == 1)) then
            flag = true
        elseif (arg2 and (arg2 == "disabled" or arg2 == "off" or arg2 == 0)) then
            flag = false
        end
        self:PetBarHandler(flag)
    end
end

--- Configuration getter
---@param info any
function MouseOverBars:GetValue(info)
    return addon.optionValues[info[1]]
end

--- Configuration number setter
---@param info any
---@param input any
function MouseOverBars:SetNumberValue(info, input)
    addon.optionValues[info[1]] = input
    addon:SaveToDB({
        configuration = addon.optionValues
    })
    addon:ComputeValues()
end

--- Configuration boolean setter
---@param info any
---@param input any
function MouseOverBars:SetBoolValue(info, input)
    addon:ApplyOnBar(addon.bars[info[1]], info[1], input)
    addon.optionValues[info[1]] = input
    addon:SaveToDB({
        configuration = addon.optionValues
    })
end

function addon:ApplyOnBar(bar, bar_name, input)
    local apply = input
    if apply == nil then
        apply = self.optionValues[bar_name]
    end

    if (apply) then
        bar:SetAlpha(addon.optionValues["AlphaMin"])
    else
        bar:SetAlpha(addon.optionValues["AlphaMax"])
    end
end

-- Initialization.
-- This fires when the addon and its settings are loaded.
function addon:OnInit()
    -- unless ignored, we want them in the list
    if (not self.db["pet_bar_ignore"]) then
        table.insert(self.bar_names, PET_BAR)
        table.insert(self.button_names, PET_ACTION_BUTTON)
    end

    -- we can access Actions Bars via _G[bar]
    -- populate bar references
    for _, barName in ipairs(self.bar_names) do
        self.bars[barName] = _G[barName]
    end
    -- populate button references
    for i, button_name in ipairs(self.button_names) do
        self.buttons[self.bar_names[i]] = {}
        if (i <= 8) then
            -- multi action bars 1 through 8 have 12 buttons
            for j = 1, 12 do
                self.buttons[self.bar_names[i]][j] = _G[button_name .. j]
            end
        else
            -- pet and stance bar only have 10
            for j = 1, 10 do
                self.buttons[self.bar_names[i]][j] = _G[button_name .. j]
            end
        end
    end
    -- this needs a manual insert, since otherwise this button is never visible
    -- it is a child of the MainMenuBar but isn't enumerated like the regular action buttons
    table.insert(self.buttons[MAIN_BAR], _G["MainMenuBarVehicleLeaveButton"])

    -- Todo: Rework
    LibStub("AceConfig-3.0"):RegisterOptionsTable("MouseOverBars", self.configOptions, nil)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("MouseOverBars", "BlizzardBars")
    -- Compute option internal values
    self:ComputeValues()

    self:RegisterChatCommand('bbm')
end

-- Enabling.
-- This fires when most of the user interface has been loaded
-- and most data is available to the user.
function addon:OnEnable()
    self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")

    -- These get called when we're dragging a spell
    self:RegisterEvent("ACTIONBAR_SHOWGRID")
    self:RegisterEvent("ACTIONBAR_HIDEGRID")

    -- in Quick Keybind mode, we wanna show bars
    -- https://www.townlong-yak.com/framexml/live/BindingUtil.lua#164
    QuickKeybindFrame:HookScript("OnShow", function()
        addon:ShowBars()
    end)
    QuickKeybindFrame:HookScript("OnHide", function()
        addon:HideBars()
    end)

    -- Same thing for Edit Mode
    -- These cause a small hicup if we call it instantly. So a tiny delay fixes that
    EditModeManagerFrame:HookScript("OnShow", function()
        C_TimerAfter(0.05, function()
            addon:ShowBars()
        end)
    end)
    EditModeManagerFrame:HookScript("OnHide", function()
        C_TimerAfter(0.05, function()
            addon:HideBars()
        end)
    end)

    -- Flyouts are more complicated, but we wanna show the parent bar while they're open
    SpellFlyout:HookScript("OnShow", function()
        addon:HandleFlyoutShow()
    end)
    SpellFlyout:HookScript("OnHide", function()
        addon:HandleFlyoutHide()
    end)

    -- initialize the mouseover shindigs
    self:HookBars()
end

-- Setup the environment
-----------------------------------------------------------
---@param eventFrame Frame
(function(eventFrame)
    addon.eventFrame = eventFrame

    local version, build, build_date, toc_version = GetBuildInfo()

    -- Let's create some constants for faster lookup
    local MAJOR, MINOR, PATCH = string_split(".", version)
    MAJOR = tonumber(MAJOR)

    -- These are defined in FrameXML/BNet.lua
    -- *Using blizzard constants if they exist,
    -- using string parsing as a fallback.
    addon.IsRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) or (MAJOR >= 10)
    addon.WoW10 = toc_version >= 100002

    -- Store major, minor, build, and TOC number.
    addon.ClientMajor = MAJOR
    addon.ClientMinor = tonumber(MINOR)
    addon.ClientBuild = tonumber(build)
    addon.ClientTocVersion = toc_version

    -- Set a relative sub-path to look for media files in.
    local Path
    function addon:SetMediaPath(path)
        Path = path
    end

    -- Should mostly be used for debugging
    function addon:Print(...)
        print("|cff33ff99" .. addonName .. ":|r", ...)
    end

    -- Simple API calls to retrieve a media file.
    -- Will honor the relative sub-path set above, if defined,
    -- and will default to the addon folder itself if not.
    -- Note that we cannot check for file or folder existence
    -- from within the WoW API, so you must make sure this is correct.
    function addon:GetMedia(name, type)
        if (Path) then
            return ([[Interface\AddOns\%s\%s\%s.%s]]):format(addonName, Path, name, type or "tga")
        else
            return ([[Interface\AddOns\%s\%s.%s]]):format(addonName, name, type or "tga")
        end
    end

    -- Parse chat input arguments
    local parse = function(msg)
        msg = string_gsub(msg, "^%s+", "") -- Remove spaces at the start.
        msg = string_gsub(msg, "%s+$", "") -- Remove spaces at the end.
        msg = string_gsub(msg, "%s+", " ") -- Replace all space characters with single spaces.
        if (string_find(msg, "%s")) then
            return string_split(" ", msg) -- If multiple arguments exist, split them into separate return values.
        else
            return msg
        end
    end

    -- This methods lets you register a chat command, and a callback function or private method name.
    -- Your callback will be called as callback(addon, editBox, commandName, ...) where (...) are all the input parameters.
    --- Register a chat command under the addon name
    ---@param command string
    ---@param callback fun(self: table, editBox: number, commandName: string, ...: string): nil
    function addon:RegisterChatCommand(command, callback)
        command = string_gsub(command, "^\\", "") -- Remove any backslash at the start.
        command = string.lower(command) -- Make it lowercase, keep it case-insensitive.
        local name = string.upper(addonName .. "_CHATCOMMAND_" .. command) -- Create a unique uppercase name for the command.
        _G["SLASH_" .. name .. "1"] = "/" .. command -- Register the chat command, keeping it lowercase.
        SlashCmdList[name] = function(msg, editBox)
            local func = self[callback] or callback or addon.OnChatCommand
            if (func) then
                func(addon, editBox, command, parse(string.lower(msg)))
            end
        end
    end

    --- Loads information on an addon based on the index
    ---@param index number
    ---@return string name
    ---@return string title
    ---@return string notes
    ---@return boolean enabled
    ---@return boolean loadable
    ---@return string reason
    ---@return string security
    function addon.GetAddOnInfo(index)
        local name, title, notes, loadable, reason, security, newVersion = GetAddOnInfo(index)
        local enabled = not (GetAddOnEnableState(UnitName("player"), index) == 0)
        return name, title, notes, enabled, loadable, reason, security
    end

    --- Check if an addon exists in the addon listing and loadable on demand
    ---@param target string Target addon name
    ---@param ignoreLoD boolean Ignore addon that are "Load on Demand"
    ---@return boolean
    function addon.IsAddOnLoadable(target, ignoreLoD)
        local targetName = string.lower(target)
        for i = 1, GetNumAddOns() do
            local name, title, notes, enabled, loadable, reason, security = addon.GetAddOnInfo(i)
            if string.lower(name) == targetName then
                if loadable or ignoreLoD then
                    return true
                end
            end
        end
        return false
    end

    ---This method lets you check if an addon WILL be loaded regardless of whether or not it currently is.
    ---This is useful if you want to check if an addon interacting with yours is enabled.
    ---My philosophy is that it's best to avoid addon dependencies in the toc file,
    ---unless your addon is a plugin to another addon, that is.
    ---@param target string Target addon's name
    ---@return boolean
    function addon.IsAddOnEnabled(target)
        local targetName = string.lower(target)
        for i = 1, GetNumAddOns() do
            local name, title, notes, enabled, loadable, reason, security = addon.GetAddOnInfo(i)
            if string.lower(name) == targetName then
                if enabled and loadable then
                    return true
                end
            end
        end
        return false
    end

    -- Event API
    -----------------------------------------------------------
    -- Proxy event registering to the addon namespace.
    -- The 'self' within these should refer to our proxy frame,
    -- which has been passed to this environment method as the 'self'.
    ---@param event WowEvent
    addon.RegisterEvent = function(_, event)
        addon.eventFrame:RegisterEvent(event)
    end
    addon.RegisterUnitEvent = function(_, ...)
        addon.eventFrame:RegisterUnitEvent(...)
    end
    ---@param event WowEvent
    addon.UnregisterEvent = function(_, event)
        addon.eventFrame:UnregisterEvent(event)
    end
    addon.UnregisterAllEvents = function(_, ...)
        addon.eventFrame:UnregisterAllEvents(...)
    end
    addon.IsEventRegistered = function(_, ...)
        addon.eventFrame:IsEventRegistered(...)
    end

    -- Event Dispatcher and Initialization Handler
    -----------------------------------------------------------
    -- Assign our event script handler,
    -- which runs our initialization methods,
    -- and dispatches event to the addon namespace.
    addon.eventFrame:RegisterEvent("ADDON_LOADED")
    addon.eventFrame:SetScript("OnEvent", function(self, event, ...)
        if (event == "ADDON_LOADED") then
            -- Nothing happens before this has fired for your addon.
            -- When it fires, we remove the event listener
            -- and call our initialization method.
            if ((...) == addonName) then
                -- Delete our initial registration of this event.
                -- Note that you are free to re-register it in any of the
                -- addon namespace methods.
                addon.eventFrame:UnregisterEvent("ADDON_LOADED")
                -- Initialize our saved variables, or use defaults if empty
                addon.db = _G[addonName .. "_DB"]
                local overwrite = false
                if overwrite or addon.db == nil then
                    -- Add default settings here
                    addon:SaveToDB({
                        pet_bar_ignore = false,
                        configuration = addon.optionValues
                    })
                end
                addon.optionValues = addon.db["configuration"]
                -- Call the initialization method.
                if (addon.OnInit) then
                    addon:OnInit()
                end
                -- If this was a load-on-demand addon, then we might be logged in already.
                -- If that is the case, directly run the enabling method.
                if (IsLoggedIn()) then
                    if (addon.OnEnable) then
                        addon:OnEnable()
                    end
                else
                    -- If this is a regular always-load addon,
                    -- we're not yet logged in, and must listen for this.
                    addon.eventFrame:RegisterEvent("PLAYER_LOGIN")
                end
                -- Return. We do not wish to forward the loading event
                -- for our own addon to the namespace event handler.
                -- That is what the initialization method exists for.
                return
            end
        elseif (event == "PLAYER_LOGIN") then
            -- This event only ever fires once on a reload,
            -- and anything you wish done at this event,
            -- should be put in the namespace enable method.
            addon.eventFrame:UnregisterEvent("PLAYER_LOGIN")
            -- Call the enabling method.
            if (addon.OnEnable) then
                addon:OnEnable()
            end
            -- Return. We do not wish to forward this
            -- to the namespace event handler.
            return
        end
        -- Forward other events than our two initialization events
        -- to the addon namespace's event handler.
        -- Note that you can always register more ADDON_LOADED
        -- if you wish to listen for other addons loading.
        if (addon[event] and type(addon[event]) == "function") then
            addon[event](...)
        else
            if (addon.OnEvent) then
                addon:OnEvent(event, ...)
            end
        end

    end)
end)(CreateFrame("Frame", addonName .. "EventFrame", UIParent))
