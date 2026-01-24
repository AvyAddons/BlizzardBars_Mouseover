-- Retrieve addon folder name, and our local, private namespace.
---@type string
local addonName = ...
---@class addon
local addon = select(2, ...)

-- Lua API
-----------------------------------------------------------
-- Up-value any lua functions used here.
local string_gsub = string.gsub
local string_find = string.find
local string_split = string.split

-- WoW API
-----------------------------------------------------------
-- Up-value any WoW functions used here.
local _G = _G
---@type table<string, function>
local SlashCmdList = _G["SlashCmdList"]

-- Setup the environment
-- This file should run last, as some values here depend on the existance of
-- some tables.
-----------------------------------------------------------
addon.eventFrame = CreateFrame("Frame", addonName .. "EventFrame", UIParent)

-- Should mostly be used for debugging
function addon:Print(...)
	print("|cff33ff99" .. addonName .. ":|r", ...)
end

function addon:Debug(...)
	--@debug@
	print("|cff33ff99" .. addonName .. ":|r", ...)
	--@end-debug@
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
---@param callback nil|fun(self: table, editBox: number, commandName: string, ...: string): nil
function addon:RegisterChatCommand(command, callback)
	command = string_gsub(command, "^\\", "")                       -- Remove any backslash at the start.
	command = string.lower(command)                                 -- Make it lowercase, keep it case-insensitive.
	local name = string.upper(addonName .. "_CHATCOMMAND_" .. command) -- Create a unique uppercase name for the command.
	_G["SLASH_" .. name .. "1"] = "/" .. command                    -- Register the chat command, keeping it lowercase.
	SlashCmdList[name] = function(msg, editBox)
		local func = self[callback] or callback or addon.OnChatCommand
		if (func) then
			func(addon, editBox, command, parse(string.lower(msg)))
		end
	end
end

-- Event API
-----------------------------------------------------------
-- Proxy event registering to the addon namespace.
-- The 'self' within these should refer to our proxy frame,
-- which has been passed to this environment method as the 'self'.
---@param event FrameEvent
addon.RegisterEvent = function(_, event) addon.eventFrame:RegisterEvent(event) end
addon.RegisterUnitEvent = function(_, ...) addon.eventFrame:RegisterUnitEvent(...) end
---@param event FrameEvent
addon.UnregisterEvent = function(_, event) addon.eventFrame:UnregisterEvent(event) end
addon.UnregisterAllEvents = function(_) addon.eventFrame:UnregisterAllEvents() end
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
			-- Initialize our saved variables, or use defaults if empty
			if (type(_G[addonName .. "_DB"]) ~= "table") then _G[addonName .. "_DB"] = {} end
			local db = _G[addonName .. "_DB"]
			for key in pairs(addon.db) do
				--  If our option is not present, set default value
				if (db[key] == nil) then db[key] = addon.db[key] end
			end
			-- Update our reference so that changed options are saved on logout
			addon.db = db
			-- Initialize config
			if (addon.InitializeConfig) then
				addon:InitializeConfig()
			end
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
		addon[event](addon, event, ...)
	else
		if (addon.OnEvent) then
			addon:OnEvent(event, ...)
		end
	end
end)
