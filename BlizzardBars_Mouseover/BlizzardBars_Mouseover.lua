-- Retrieve addon folder name, and our local, private namespace.
---@type string, table
local addonName, addon = ...

-- Fetch the localization table
---@type table<string, string>
local L = addon.L

--@debug@
_G[addonName] = addon
--@end-debug@

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
local S_MAIN_BAR = "MainMenuBar"

-- Your default settings.
-----------------------------------------------------------
-- Note that anything changed will be saved to disk when you reload the user
-- interface, or exit the game, and those saved changes will override your
-- defaults here.
-- * You should access saved settings by using `db[key]`
-- * Don't put frame handles or other widget references in here,
--   just strings, numbers, and booleans. Tables also work.
local db = (function(db) _G[addonName .. "_DB"] = db; return db end)({
	-- Put your default settings here
})


-- Utility Functions
-----------------------------------------------------------
-- Add utility functions like time formatting and similar here.

--- Fires a callback after `delay` seconds has passed.
---@param fn function Void callback
---@param delay number Delay in seconds
---@return table timer The timer table
function addon:Timer(fn, delay)
	-- C_TimerAfter doesn't allow anything below
	if delay < 0.01 then delay = 0.01 end

	local timer = {
		delay = delay,
		fn = fn,
		ends = GetTime() + delay,
		cancelled = false,
	}

	timer.callback = function()
		if not timer.cancelled then timer.fn() end
	end

	C_TimerAfter(delay, timer.callback)
	return timer
end

function addon:CancelTimer(barKey)
	local timer = self.timers[barKey]
	if timer then timer.cancelled = true end
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
			local index = indexOf(self.buttonNames, string_gsub(parent_name, "%d", ""))

			-- we have the bloody thing!
			if (index) then return self.bar_names[index] end
		end
	end
	return nil
end

-- Addon API
-----------------------------------------------------------

--- Securely hooks into a frame's OnEnter and OnLeave to show/hide.
---@param frame Frame Base frame on which to hook
---@param alpha_target Frame Frame whose alpha should change
---@param bar_name string Name of the base frame
function addon:SecureHook(frame, alpha_target, bar_name)
	-- because of scoping, we can't declare the bypass here
	frame:HookScript("OnEnter", function()
		-- if we're dragonriding and this is the main bar, bypass the function
		local mainBarBypass = (self.dragonriding and bar_name == S_MAIN_BAR)
		-- ad-hoc bypass for random reason
		local adHocBypass = (self.bypass == bar_name)
		if (addon.hook and not mainBarBypass and not adHocBypass) then
			addon:CancelTimer(bar_name)
			alpha_target:SetAlpha(1)
		end
	end)
	frame:HookScript("OnLeave", function()
		-- if we're dragonriding and this is the main bar, bypass the function
		local mainBarBypass = (self.dragonriding and bar_name == S_MAIN_BAR)
		-- ad-hoc bypass for random reason
		local adHocBypass = (self.bypass == bar_name)
		if (addon.hook and not mainBarBypass and not adHocBypass) then
			addon.timers[bar_name] = addon:Timer(function()
				alpha_target:SetAlpha(0)
			end, 1.2)
		end
	end)
end

--- Hook all bars
function addon:HookBars()
	self:ResumeCallbacks()
	-- these secure hooks are automatically de-hook on reload/relog, we can ignore OnDisable
	for bar_name, bar in pairs(self.bars) do
		-- hide them all
		bar:SetAlpha(0)
		-- hook into mouseover for bar and buttons
		self:SecureHook(bar, bar, bar_name)
		for _, button in pairs(self.buttons[bar_name]) do
			self:SecureHook(button, bar, bar_name)
			self:SetBling(button.cooldown, false)
		end
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
---@param render boolean
function addon:SetBlingRender(bar_name, render)
	if not self.buttons[bar_name] then return end
	for _, button in ipairs(self.buttons[bar_name]) do
		self:SetBling(button.cooldown, render)
	end
end

--- Resumes callbacks
function addon:ResumeCallbacks()
	self.hook = true
end

--- Pauses callbacks without actually unhooking them
function addon:PauseCallbacks()
	self.hook = false
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
		bar:SetAlpha(0)
		self:SetBlingRender(bar_name, false)
	end
end

--- Toggle bar visibility and (un)register grid events
function addon:ToggleBars()
	if addon.hook then
		self:ShowBars()
		self:UnregisterEvent("ACTIONBAR_SHOWGRID")
		self:UnregisterEvent("ACTIONBAR_HIDEGRID")
	else
		self:HideBars()
		self:RegisterEvent("ACTIONBAR_SHOWGRID")
		self:RegisterEvent("ACTIONBAR_HIDEGRID")
	end
end

--- Show main vehicle bar
function addon:Dragonriding()
	-- this shit is DF release only
	if not self.WoW10 then return end

	if (IsMounted() and HasBonusActionBar()) then
		-- we're dragonriding
		self.dragonriding = true
		-- show main bar
		self.bars[S_MAIN_BAR]:SetAlpha(1)
	else
		-- if not dragonriding, hide everything again
		self.dragonriding = false
		self.bars[S_MAIN_BAR]:SetAlpha(0)
	end
end

function addon:HandleFlyoutShow()
	-- this returns nil if the parent isn't one of the bars we're hiding
	self.bypass = self:GetFlyoutParent()
	self:CancelTimer(self.bypass)
	self.bars[self.bypass]:SetAlpha(1)
end

function addon:HandleFlyoutHide()
	local prev_bypass = self.bypass
	if (prev_bypass) then
		self.bypass = nil
		addon.timers[prev_bypass] = addon:Timer(function()
			self.bars[prev_bypass]:SetAlpha(0)
		end, 1.2)
	end
end

-- Addon Tables
-----------------------------------------------------------

addon.timers = {}
addon.bars = {}
addon.buttons = {}
addon.bar_names = {
	S_MAIN_BAR,
	"MultiBarBottomLeft",
	"MultiBarBottomRight",
	"MultiBarRight",
	"MultiBarLeft",
	"MultiBar5",
	"MultiBar6",
	"MultiBar7",
	"PetActionBar",
	"StanceBar",
}
addon.buttonNames = {
	"ActionButton",
	"MultiBarBottomLeftButton",
	"MultiBarBottomRightButton",
	"MultiBarRightButton",
	"MultiBarLeftButton",
	"MultiBar5Button",
	"MultiBar6Button",
	"MultiBar7Button",
	"PetActionButton",
	"StanceButton",
}

-- these are bypasses and control hover callbacks
--- Global hover bypass
addon.hook = true
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
---@param command string The name of the slash command type in.
---@param ... string Any additional arguments passed to your command, all as strings.
function addon:OnChatCommand(editBox, command, ...)
end

-- Initialization.
-- This fires when the addon and its settings are loaded.
function addon:OnInit()
	-- we can access Actions Bars via _G[bar]
	-- populate bar references
	for _, barName in ipairs(self.bar_names) do
		self.bars[barName] = _G[barName]
	end
	-- populate button references
	for i, buttonName in ipairs(self.buttonNames) do
		self.buttons[self.bar_names[i]] = {}
		if (i <= 8) then
			-- multi action bars 1 through 8 have 12 buttons
			for j = 1, 12 do
				self.buttons[self.bar_names[i]][j] = _G[buttonName .. j]
			end
		else
			-- pet and stance bar only have 10
			for j = 1, 10 do
				self.buttons[self.bar_names[i]][j] = _G[buttonName .. j]
			end
		end
	end

	self:RegisterChatCommand('togglemo', self.ToggleBars)
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
	EditModeManagerFrame:HookScript("OnShow", function() addon:ShowBars() end)
	EditModeManagerFrame:HookScript("OnHide", function() addon:HideBars() end)

	-- Flyouts are more complicated, but we wanna show the parent bar while they're open
	SpellFlyout:HookScript("OnShow", function() addon:HandleFlyoutShow() end)
	SpellFlyout:HookScript("OnHide", function() addon:HandleFlyoutHide() end)

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
	addon.RegisterEvent = function(_, event) addon.eventFrame:RegisterEvent(event) end
	addon.RegisterUnitEvent = function(_, ...) addon.eventFrame:RegisterUnitEvent(...) end
	---@param event WowEvent
	addon.UnregisterEvent = function(_, event) addon.eventFrame:UnregisterEvent(event) end
	addon.UnregisterAllEvents = function(_, ...) addon.eventFrame:UnregisterAllEvents(...) end
	addon.IsEventRegistered = function(_, ...) addon.eventFrame:IsEventRegistered(...) end

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
