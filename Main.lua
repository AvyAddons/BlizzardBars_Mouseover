---@class addon
local addon = select(2, ...)
addon.shortName = "BlizzardBars"

--@debug@
_G["BBM"] = addon
--@end-debug@

-- Lua API
-----------------------------------------------------------
-- Up-value any lua functions used here.
local ipairs = ipairs

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
local Settings_OpenToCategory = Settings.OpenToCategory

-- Constants
-----------------------------------------------------------
local MAIN_BAR = "MainMenuBar"
addon.MAIN_BAR = MAIN_BAR
local PET_BAR = "PetActionBar"
addon.PET_BAR = PET_BAR
local PET_ACTION_BUTTON = "PetActionButton"
addon.PET_ACTION_BUTTON = PET_ACTION_BUTTON

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
--- Skyriding hover bypass
addon.skyriding = false
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
	if (event == "PLAYER_ENTERING_WORLD" or event == "UNIT_POWER_BAR_SHOW" or event == "UNIT_POWER_BAR_HIDE") then
		self:Skyriding(event, ...)
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
		Settings_OpenToCategory(addon.category)
	elseif (arg1 == "config") then
		Settings_OpenToCategory(addon.category)
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
	-- Chat commands
	self:RegisterChatCommand('bbm')
end

-- Enabling.
-- This fires when most of the user interface has been loaded
-- and most data is available to the user.
function addon:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("UNIT_POWER_BAR_SHOW")
	self:RegisterEvent("UNIT_POWER_BAR_HIDE")

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

	addon:Skyriding()
	addon:HookBars()
end
