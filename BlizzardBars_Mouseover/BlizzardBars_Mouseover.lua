-- Retrieve addon folder name, and our local, private namespace.
---@type string, table
local addonName, addon = ...

-- Fetch the localization table
---@type table<string, string>
local L = addon.L


-- Lua API
-----------------------------------------------------------
-- Up-value any lua functions used here.
local tonumber = tonumber
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


-- Callbacks
-----------------------------------------------------------
-- Add functions called multiple times by your reactive addon code here.


-- Addon API
-----------------------------------------------------------
-- Add any extra addon environment methods here.


-- Addon Core
-----------------------------------------------------------
-- Your event handler.
-- Any events you add should be handled here.
--- @param event string The name of the event that fired.
--- @param ... unknown Any payloads passed by the event handlers.
function addon:OnEvent(event, ...)
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
	-- Do any parsing of saved settings here.
	-- This is also a good place to create your frames and objects,
	-- as well as register chat commands.
end

-- Enabling.
-- This fires when most of the user interface has been loaded
-- and most data is available to the user.
function addon:OnEnable()
	-- Register your events here.
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
	addon.RegisterEvent = function(_, ...) addon.eventFrame:RegisterEvent(...) end
	addon.RegisterUnitEvent = function(_, ...) addon.eventFrame:RegisterUnitEvent(...) end
	addon.UnregisterEvent = function(_, ...) addon.eventFrame:UnregisterEvent(...) end
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
