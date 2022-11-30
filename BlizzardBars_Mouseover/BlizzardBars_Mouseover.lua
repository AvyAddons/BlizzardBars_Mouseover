-- Retrieve addon folder name, and our local, private namespace.
---@transition string, table
local addonName, addon = ...
local addonShortName = "BlizzardBars"

-- Fetch the localization table
---@transition table<string, string>
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
---@transition table<string, function>
local SlashCmdList = _G["SlashCmdList"]
local GetBuildInfo = _G.GetBuildInfo
local GetAddOnInfo = _G.GetAddOnInfo
local GetNumAddOns = _G.GetNumAddOns
local GetAddOnEnableState = _G.GetAddOnEnableState
local GetTime = _G.GetTime
local C_TimerAfter = _G.C_Timer.After
---@transition Frame
local QuickKeybindFrame = _G["QuickKeybindFrame"]
---@transition Frame
local EditModeManagerFrame = _G["EditModeManagerFrame"]
---@transition Frame
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

--- Bypass transformation for specific bars
---@param bar_name any
function addon:CheckBypass(bar_name)
    -- if we're dragonriding and this is the main bar, bypass the function
    local dragonridingBypass = (self.dragonriding and bar_name == MAIN_BAR)
    -- ad-hoc bypass of any given bar
    local adHocBypass = (self.bypass == bar_name or addon.optionValues[bar_name] == false)

    return not (dragonridingBypass or adHocBypass)
end

--- Securely hooks into a frame's OnEnter and OnLeave to show/hide.
---@param frame Frame Base frame on which to hook
---@param bar Frame Frame whose alpha should change
---@param bar_name string Name of the base frame
function addon:SecureHook(frame, bar, bar_name)
    frame:HookScript("OnEnter", function()
        if addon.enabled then
            addon:FadeBar("FadeIn", bar, bar_name)
        end
    end)

    frame:HookScript("OnLeave", function()
        if addon.enabled then
            addon:FadeBar("FadeOut", bar, bar_name)
        end
    end)
end

function addon:FadeBar(transition, bar, bar_name)
    local bar_collection = {bar_name}
    if self.optionValues["LinkActionBars"] then
        bar_collection = self.bar_names
    end
    for _, bar_name in pairs(bar_collection) do
        if self.optionValues[bar_name] and self:CheckBypass(bar_name) then
            bar = self.bars[bar_name]
            addon:CancelTimer(bar_name)
            if transition == "FadeOut" then
                addon.timers[bar_name] = addon:FadeOutBarTimer(bar, bar_name)
            elseif transition == "FadeIn" then
                addon.timers[bar_name] = addon:FadeInBarTimer(bar, bar_name)
            else
                error("Transition '" .. transition .. "' not defined")
            end
        end
    end
end

--- Apply fade-in for a bar or a group of bars using timers
---@param bar any Bar instance
---@param bar_name any Bar name
function addon:FadeInBarTimer(bar, bar_name)
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
        bar:SetAlpha(alpha)
    end, (addon.optionValues["FadeInDelay"] or 0), addon.optionValues["MaxRefreshRate"])
    return timer
end

--- Apply fade-out for a bar or a group of bars using timers
---@param bar any Bar instance
---@param bar_name any Bar name
function addon:FadeOutBarTimer(bar, bar_name)
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
        bar:SetAlpha(alpha)
    end, (addon.optionValues["FadeOutDelay"] or 0), addon.optionValues["MaxRefreshRate"])
    return timer
end

---Securely hook a bar and its buttons
---@param bar Frame
---@param bar_name string
function addon:HookBar(bar, bar_name)
    -- Ignore some bars according to configuration to apply min alpha
    self:ApplyOnBar(bar, bar_name)
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
        self:ApplyOnBar(bar, bar_name)
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
    elseif self.dragonriding then
        -- elseif (not IsMounted() and self.dragonriding) then
        -- if we were dragonriding and stopped, hide everything again
        self.dragonriding = false
        self:ApplyOnBar(self.bars[MAIN_BAR], MAIN_BAR)
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
    if (transition(flag) == string) then
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
---@transition string|nil
addon.bypass = nil

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
    StanceBar = true,
    PetActionBar = true,
    LinkActionBars = false,
    FadeInDelay = 0,
    FadeInDuration = 0.1,
    FadeOutDelay = 0,
    FadeOutDuration = 0.1,
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
    local alphaRange = math.abs(self.optionValues["AlphaMax"] - self.optionValues["AlphaMin"])
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
        self:Dragonriding()
    elseif (event == "ACTIONBAR_SHOWGRID") then
        self:ShowBars()
    elseif (event == "ACTIONBAR_HIDEGRID") then
        self:HideBars()
    end
end

-- Your chat command handler.
---@param editBox table|frame The editbox the command was entered into.
---@param command string The name of the slash command transition in.
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

function addon:ApplyOnBar(bar, bar_name)
    if bar == nil or bar_name == nil or (not self:CheckBypass(bar_name)) then
        if bar ~= nil then
            bar:SetAlpha(1)
        end
        return
    end
    local apply = self.optionValues[bar_name]
    if (apply) then
        bar:SetAlpha(addon.optionValues["AlphaMin"])
    else
        bar:SetAlpha(1)
    end
end

--- Create checkbox for an action bar to active the mouseover settings
---@param parent any In-game option window
---@param name any Bar name
---@param title any Check box text
---@param x any Position on setting window x axis
---@param y any Position on setting window y axis
---@param default any 
function addon:CreateButton(parent, name, title, x, y, default)
    if default == nil then
        default = true
    end
    local cb = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
    self = cb
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(title)
    if addon.optionValues[name] ~= nil then
        default = addon.optionValues[name]
    end
    cb:SetChecked(default)
    function self:OnCheckBoxClicked()
        addon.optionValues[name] = self:GetChecked()
        addon:SaveToDB({
            configuration = addon.optionValues
        })
        addon:ApplyOnBar(addon.bars[name], name)
    end
    cb:SetScript("OnClick", self.OnCheckBoxClicked)
    return cb
end

--- Create a section in the setting window
---@param parent any In-game option window
---@param name any 
---@param title any Section name
---@param y any Position on setting window y axis
function addon:CreateHeader(parent, name, title, y)
    local header = parent:CreateFontString("ARTWORK", nil, "GameFontNormalLarge")
    header:SetPoint("TOP", -20, y)
    header:SetText(title)
    local line = parent:CreateTexture()
    line:SetTexture("Interface/BUTTONS/WHITE8X8")
    line:SetColorTexture(255, 255, 255, 0.4)
    line:SetSize(630, 0.6)
    line:SetPoint("TOP", -7, y - 23)
    return header
end

--- Round a value to the nearest percentile
---@param value any Sliders values
function addon:RoundToNearestPercentile(value)
    local value = value * 100
    local remain = math.fmod(value, 1)
    if remain < 0.5 then
        value = value - remain
    elseif remain > 0.5 then
        value = value + 1 - remain
    end
    return value / 100
end

--- Create a slider in the setting window
---@param parent any In-game option window
---@param name any 
---@param title any Slider name
---@param x any Position on setting window x axis
---@param y any Position on setting window y axis
---@param suffix any 
---@param default any
function addon:CreateSlider(parent, name, title, x, y, suffix, default)
    if suffix == nil then
        suffix = ""
    end
    if default == nil then
        default = 0
    end
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    self = slider
    slider.currentValue = -1
    slider:SetOrientation("HORIZONTAL")
    slider:SetWidth(250)
    slider:SetHeight(15)
    getglobal(name .. "Low"):SetText("0" .. suffix)
    getglobal(name .. "High"):SetText("1" .. suffix)
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetMinMaxValues(0, 1)
    if addon.optionValues[name] ~= nil then
        default = addon.optionValues[name]
    end
    slider.Text:SetText(title .. " (" .. default .. suffix .. ")")
    slider:SetValue(default)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    function self:OnSliderValueChanged(value)
        local roundValue = addon:RoundToNearestPercentile(value)
        if roundValue == self.currentValue then
            return
        end
        self.currentValue = roundValue
        self.Text:SetText(title .. " (" .. roundValue .. suffix .. ")")
        addon.optionValues[name] = roundValue
        addon:SaveToDB({
            configuration = addon.optionValues
        })
        addon:ComputeValues()
        for _, bar_name in pairs(addon.bar_names) do
            addon:ApplyOnBar(addon.bars[bar_name], bar_name)
        end
    end
    slider:SetScript("OnValueChanged", self.OnSliderValueChanged)
    return slider
end

--- Create the in-game addon option window
function addon:CreateConfigPanel()
    local panel = CreateFrame("Frame")
    panel.name = addonShortName
    InterfaceOptions_AddCategory(panel) -- see InterfaceOptions API

    self:CreateHeader(panel, "ActionBars", "Action Bars", -10)

    -- Button to activate/deactivate mouseover
    self:CreateButton(panel, "MainMenuBar", "Action Bar 1", 20, -50)
    self:CreateButton(panel, "MultiBarBottomLeft", "Action Bar 2", 193, -50)
    self:CreateButton(panel, "MultiBarBottomRight", "Action Bar 3", 366, -50)
    self:CreateButton(panel, "MultiBarRight", "Action Bar 4", 540, -50)
    self:CreateButton(panel, "MultiBarLeft", "Action Bar 5", 20, -85)
    self:CreateButton(panel, "MultiBar5", "Action Bar 6", 193, -85)
    self:CreateButton(panel, "MultiBar6", "Action Bar 7", 366, -85)
    self:CreateButton(panel, "MultiBar7", "Action Bar 8", 540, -85)
    self:CreateButton(panel, "StanceBar", "Stance Bar", 20, -120)
    self:CreateButton(panel, "PetActionBar", "Pet Action Bar", 193, -120)
    self:CreateButton(panel, "LinkActionBars", "Link Action Bars", 20, -165)

    self:CreateHeader(panel, "FadeInTimes", "Fade in times", -210)

    self:CreateSlider(panel, "FadeInDelay", "Fade in delay", 20, -260, "s")
    self:CreateSlider(panel, "FadeInDuration", "Fade in duration", 360, -260, "s")

    self:CreateHeader(panel, "FadeOutTimes", "Fade out times", -300)

    self:CreateSlider(panel, "FadeOutDelay", "Fade out delay", 20, -350, "s")
    self:CreateSlider(panel, "FadeOutDuration", "Fade out duration", 360, -350, "s")

    self:CreateHeader(panel, "Alphas", "Alphas", -390)

    self:CreateSlider(panel, "AlphaMin", "Minimum Alpha", 20, -440)
    self:CreateSlider(panel, "AlphaMax", "Maximum Alpha", 360, -440)

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
    -- Compute option internal values
    self:ComputeValues()
    -- Initialize Blizzard options panel
    self:CreateConfigPanel()
    -- Chat commands
    self:RegisterChatCommand('bbm')
    self:RegisterChatCommand('bbc', function()
        InterfaceOptionsFrame_OpenToCategory(addonShortName)
    end)
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

    -- Initialize bindings after a short delay to allow for DragonRiding() to get the proper values (i.e. HasBonusActionBar())
    C_TimerAfter(0.05, function()
        self:Dragonriding()
        self:HookBars()
    end)
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
    function addon:GetMedia(name, transition)
        if (Path) then
            return ([[Interface\AddOns\%s\%s\%s.%s]]):format(addonName, Path, name, transition or "tga")
        else
            return ([[Interface\AddOns\%s\%s.%s]]):format(addonName, name, transition or "tga")
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
        if (addon[event] and transition(addon[event]) == "function") then
            addon[event](...)
        else
            if (addon.OnEvent) then
                addon:OnEvent(event, ...)
            end
        end

    end)
end)(CreateFrame("Frame", addonName .. "EventFrame", UIParent))
