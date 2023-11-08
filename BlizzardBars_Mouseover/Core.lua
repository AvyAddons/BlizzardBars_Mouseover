-- Retrieve addon folder name, and our local, private namespace.
---@type string, table
local addonName, addon = ...

-- Fetch the localization table
---@type table<string, string>
local L = addon.L

--@debug@
_G["BBM"] = addon
--@end-debug@

-- Lua API
-----------------------------------------------------------
-- Up-value any lua functions used here.
local ipairs = ipairs
local pairs = pairs
local string_gsub = string.gsub
local string_find = string.find

-- WoW API
-----------------------------------------------------------
-- Up-value any WoW functions used here.
local _G = _G
local C_TimerAfter = _G.C_Timer.After
---@type Frame
local QuickKeybindFrame = _G["QuickKeybindFrame"]
---@type Frame
local EditModeManagerFrame = _G["EditModeManagerFrame"]
---@type Frame
local SpellFlyout = _G["SpellFlyout"]
---@type function
local InterfaceOptionsFrame_OpenToCategory = _G.InterfaceOptionsFrame_OpenToCategory

-- Constants
-----------------------------------------------------------
local MAIN_BAR = "MainMenuBar"
local PET_BAR = "PetActionBar"
local PET_ACTION_BUTTON = "PetActionButton"

-- Utility Functions
-----------------------------------------------------------
-- Add utility functions like time formatting and similar here.

--- Fires a callback after `delay` seconds has passed.
---@param fn function Void callback
---@param delay number Delay in seconds
---@param every number|nil repeat Every in seconds
---@return table timer The timer table
function addon:Timer(fn, delay, every)
	-- C_TimerAfter doesn't allow anything below
	if delay < 0.01 then delay = 0.01 end

	local timer = {
		name = "",
		delay = delay,
		fn = fn,
		cancelled = false,
	}

	timer.callback = function()
		if not timer.cancelled then
			timer.fn()
			if (every == nil and timer.post_call and type(timer.post_call) == "function") then timer.post_call() end
			if (every ~= nil) then C_TimerAfter(every, timer.callback) end
		end
	end

	C_TimerAfter(delay, timer.callback)
	return timer
end

--- Cancel a timer by the bar name
---@param bar_name string
---@param post_call_flag boolean|nil If true, will execute the post-call method
function addon:CancelTimer(bar_name, post_call_flag)
	local timer = self.timers[bar_name]
	if timer then timer.cancelled = true end
	if (post_call_flag == true and timer.post_call) then timer.post_call() end
end

function addon:CancelAllTimers()
	for _, timer in pairs(self.timers) do
		timer.cancelled = true
	end
end

function addon:GetFlyoutParent()
	if (SpellFlyout:IsShown()) then
		local parent = SpellFlyout:GetParent()
		local parent_name = parent:GetName() or ""
		if (string_find(parent_name, "([Bb]utton)%d")) then
			local index = (function(array, value)
				for i, v in ipairs(array) do if v == value then return i end end
				return nil
			end)(self.button_names, string_gsub(parent_name, "%d", ""))
			if (index) then return self.bar_names[index] end
		end
	end
	return nil
end

-- Addon API
-----------------------------------------------------------

--- Bypass transformation for specific bars
---@param bar_name string
function addon:CheckBypass(bar_name)
	-- if we're dragonriding and this is the main bar, bypass the function
	local dragonridingBypass = (self.dragonriding and bar_name == MAIN_BAR)
	-- ad-hoc bypass of any given bar
	local adHocBypass = (self.bypass == bar_name or addon.db[bar_name] == false)

	return not (dragonridingBypass or adHocBypass)
end

---Apply alpha to a given bar
---@param bar Frame
---@param bar_name string
function addon:ApplyOnBar(bar, bar_name)
	if (bar == nil) then return end
	if (bar_name == nil or (not self:CheckBypass(bar_name))) then
		bar:SetAlpha(1)
		return
	end
	if (self.db[bar_name]) then
		bar:SetAlpha(addon.db.AlphaMin)
	else
		bar:SetAlpha(1)
	end
end

--- Securely hooks into a frame's OnEnter and OnLeave to show/hide.
---@param frame Frame Base frame on which to hook
---@param bar Frame Frame whose alpha should change
---@param bar_name string Name of the base frame
function addon:SecureHook(frame, bar, bar_name)
	frame:HookScript("OnEnter", function()
		if addon.enabled then
			-- Always immediately start the fade-in, regardless of a running fade-out
			addon:CancelTimer(bar_name)
			addon:FadeBar("FadeIn", bar, bar_name)
		end
	end)

	frame:HookScript("OnLeave", function()
		if addon.enabled then
			local timer = addon.timers[bar_name]
			if (timer and not timer.cancelled and timer.name == "FadeIn") then
				timer.post_call = function() addon:FadeBar("FadeOut", bar, bar_name) end
			else
				addon:FadeBar("FadeOut", bar, bar_name)
			end
		end
	end)
end

---Fades a bar with a given transition
---@param transition "FadeIn"|"FadeOut"
---@param bar Frame
---@param bar_name string
function addon:FadeBar(transition, bar, bar_name)
	--@debug@
	assert(transition == "FadeIn" or transition == "FadeOut", "Unkown transition")
	--@end-debug@

	if self.db["LinkActionBars"] then
		for _, linked_bar_name in ipairs(self.bar_names) do
			if self.db[linked_bar_name] and self:CheckBypass(linked_bar_name) then
				local linked_bar = self.bars[linked_bar_name]
				addon.timers[linked_bar_name] = addon[transition .. "BarTimer"](self, linked_bar, linked_bar_name)
				addon.timers[linked_bar_name].name = transition
			end
		end
	else
		if self.db[bar_name] and self:CheckBypass(bar_name) then
			addon.timers[bar_name] = addon[transition .. "BarTimer"](self, bar, bar_name)
			addon.timers[bar_name].name = transition
		end
	end
end

--- Apply fade-in for a bar or a group of bars using timers
---@param bar any Bar instance
---@param bar_name any Bar name
function addon:FadeInBarTimer(bar, bar_name)
	local alpha = addon.fades[bar_name]
	if alpha == nil then
		alpha = addon.db["AlphaMin"]
		addon.fades[bar_name] = alpha
	end
	local timer = addon:Timer(function()
		alpha = alpha + addon.db.FadeInAlphaStep
		if alpha >= addon.db["AlphaMax"] then
			addon:CancelTimer(bar_name, true)
			alpha = addon.db["AlphaMax"]
		end
		addon.fades[bar_name] = alpha
		bar:SetAlpha(alpha)
	end, (addon.db["FadeInDelay"] or 0), addon.db["MaxRefreshRate"])
	return timer
end

--- Apply fade-out for a bar or a group of bars using timers
---@param bar any Bar instance
---@param bar_name any Bar name
function addon:FadeOutBarTimer(bar, bar_name)
	local alpha = addon.fades[bar_name]
	if alpha == nil then
		alpha = addon.db["AlphaMax"]
		addon.fades[bar_name] = alpha
	end
	local timer = addon:Timer(function()
		alpha = alpha - addon.db.FadeOutAlphaStep
		if alpha <= addon.db["AlphaMin"] then
			addon:CancelTimer(bar_name)
			alpha = addon.db["AlphaMin"]
		end
		addon.fades[bar_name] = alpha
		bar:SetAlpha(alpha)
	end, (addon.db["FadeOutDelay"] or 0), addon.db["MaxRefreshRate"])
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
	if not cooldown then return end
	cooldown:SetDrawBling(flag)
end

---Sets the bling for each button in a bar
---@param bar_name string
---@param flag boolean
function addon:SetBlingRender(bar_name, flag)
	if not self.buttons[bar_name] then return end
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

--- Show main vehicle bar when dragonriding
---@param event WowEvent|nil Event name
---@param isInitialLogin boolean|nil Only defined when event is 'PLAYER_ENTERING_WORLD'
function addon:Dragonriding(event, isInitialLogin)
	if (not self.enabled) then
		return
	end

	if event == "PLAYER_ENTERING_WORLD" and isInitialLogin == true then
		C_Timer.After(2, self.Dragonriding)
		return
	end

	-- shamelessly copied from WeakAuras
	-- https://github.com/WeakAuras/WeakAuras2/blob/acd04c2e8e495ed5e9237db219aa01aeff195bc0/WeakAuras/Dragonriding.lua
	local dragonridingSpellIds = C_MountJournal.GetCollectedDragonridingMounts()
	self.dragonriding = false
	if IsMounted() then
		for _, mountId in ipairs(dragonridingSpellIds) do
			local spellId = select(2, C_MountJournal.GetMountInfoByID(mountId))
			if C_UnitAuras.GetPlayerAuraBySpellID(spellId) then
				self.dragonriding = true
			end
		end
	end

	if (self.dragonriding) then
		-- show main bar
		self.bars[MAIN_BAR]:SetAlpha(1)
	else
		self:ApplyOnBar(self.bars[MAIN_BAR], MAIN_BAR)
	end
end

function addon:HandleFlyoutShow()
	-- ignore when bypass enabled
	if (not self.enabled) then return end
	-- this returns nil if the parent isn't one of the bars we're hiding
	self.bypass = self:GetFlyoutParent()
	self:CancelTimer(self.bypass)
	self.bars[self.bypass]:SetAlpha(1)
end

function addon:HandleFlyoutHide()
	-- ignore when bypass enabled
	if (not self.enabled) then return end
	local prev_bypass = self.bypass
	if (prev_bypass) then
		self.bypass = nil
		addon:FadeBar("FadeOut", self.bars[prev_bypass], prev_bypass)
	end
end

-- Addon Tables
-----------------------------------------------------------

--- Map for created timers. Keys should be the bar names.
addon.timers = {}
--- Map for current bar alpha values. Keys are bar names.
addon.fades = {}
--- Reference map for all bars enumerated in `bar_names`.
addon.bars = {}
--- Reference map for all bar buttons enumerated in `button_names`.
addon.buttons = {}
addon.bar_names = {
	MAIN_BAR,
	"MultiBarBottomLeft",
	"MultiBarBottomRight",
	"MultiBarRight",
	"MultiBarLeft",
	"MultiBar5",
	"MultiBar6",
	"MultiBar7",
	"StanceBar",
	PET_BAR,
}
addon.button_names = {
	"ActionButton",
	"MultiBarBottomLeftButton",
	"MultiBarBottomRightButton",
	"MultiBarRightButton",
	"MultiBarLeftButton",
	"MultiBar5Button",
	"MultiBar6Button",
	"MultiBar7Button",
	"StanceButton",
	PET_ACTION_BUTTON,
}

-- these are bypasses and control hover callbacks
--- Global hover bypass
addon.enabled = true
--- Dragonriding hover bypass
addon.dragonriding = false
--- Generic bypass, currently in use for flyouts
---@type string|nil
addon.bypass = nil


-- Addon Core
-----------------------------------------------------------

-- Your event handler.
-- Any events you add should be handled here.
--- @param event WowEvent The name of the event that fired.
--- @param ... unknown Any payloads passed by the event handlers.
function addon:OnEvent(event, ...)
	if (event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "PLAYER_ENTERING_WORLD") then
		self:Dragonriding(event, ...)
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
	function PrintCommands()
		addon:Print([[Available commands:
        - |cff24acf2/bbm|r: Opens the configuration panel
        - |cff24acf2/bbm config|r: Opens the configuration panel
        - |cff24acf2/bbm toggle|r: Make all bars visible temporarily (until /reload or the next toggle)
        - |cff24acf2/bbm help|r: Displays a list of commands
        ]])
	end

	local arg1, arg2 = ...
	if (not arg1 or arg1 == "") then
		InterfaceOptionsFrame_OpenToCategory(addon.shortName)
	elseif (arg1 == "config") then
		InterfaceOptionsFrame_OpenToCategory(addon.shortName)
	elseif (arg1 == "toggle") then
		self:ToggleBars()
	elseif (arg1 == "help") then
		PrintCommands()
	else
		self:Print("Command not recognized.")
		PrintCommands()
	end
end

-- Initialization.
-- This fires when the addon and its settings are loaded.
function addon:OnInit()
	-- we sometimes change the options, hence the need to migrate tables
	self:MigrateDB()

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
	-- Initialize Blizzard options panel
	self:CreateConfigPanel()
	-- Chat commands
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
	QuickKeybindFrame:HookScript("OnShow", function() addon:ShowBars() end)
	QuickKeybindFrame:HookScript("OnHide", function() addon:HideBars() end)

	-- Same thing for Edit Mode
	-- These cause a small hicup if we call it instantly. So a tiny delay fixes that
	EditModeManagerFrame:HookScript("OnShow", function() C_TimerAfter(0.05, function() addon:ShowBars() end) end)
	EditModeManagerFrame:HookScript("OnHide", function() C_TimerAfter(0.05, function() addon:HideBars() end) end)

	-- Flyouts are more complicated, but we wanna show the parent bar while they're open
	SpellFlyout:HookScript("OnShow", function() addon:HandleFlyoutShow() end)
	SpellFlyout:HookScript("OnHide", function() addon:HandleFlyoutHide() end)

	-- Initialize bindings after a short delay to allow for DragonRiding() to get the proper values (i.e. HasBonusActionBar())
	C_TimerAfter(0.05, function()
		self:Dragonriding()
		self:HookBars()
	end)
end
