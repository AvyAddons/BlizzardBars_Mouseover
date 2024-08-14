-- Retrieve addon folder name, and our local, private namespace.
---@type string
local addonName = ...
---@class addon
local addon = select(2, ...)

-- Lua API
-----------------------------------------------------------
-- Upvalue any lua functions used here.
local pairs = pairs

-- WoW API
-----------------------------------------------------------
-- Upvalue any WoW functions used here.
local _G = _G
local GetLocale = _G.GetLocale

-- Localization system.
-----------------------------------------------------------
-- Do not modify the function,
-- just the locales in the table below!
---@type table<string, string>
local L = (function(tbl, defaultLocale)
	local gameLocale = GetLocale()                  -- The locale currently used by the game client.
	local L = tbl[gameLocale] or tbl[defaultLocale] -- Get the localization for the current locale, or use your default.
	-- Replace the boolean 'true' with the key,
	-- to simplify locale creation and reduce space needed.
	for i in pairs(L) do
		if (L[i] == true) then
			L[i] = i
		end
	end
	-- If the game client is in another locale than your default,
	-- fill in any missing localization in the client's locale
	-- with entries from your default locale.
	if (gameLocale ~= defaultLocale) then
		for i, msg in pairs(tbl[defaultLocale]) do
			if (not L[i]) then
				-- Replace the boolean 'true' with the key,
				-- to simplify locale creation and reduce space needed.
				L[i] = (msg == true) and i or msg
			end
		end
	end
	return L
end)({
	-- ENTER YOUR LOCALIZATION HERE!
	-----------------------------------------------------------
	-- * Note that you MUST include a full table for your primary/default locale!
	-- * Entries where the value (to the right) is the boolean 'true',
	--   will use the key (to the left) as the value instead!
	["enUS"] = {
		[addonName] = true,
		["Action Bars"] = true,
		["Fade Times"] = true,
		["Transparency"] = true,
		["Action Bar 1"] = true,
		["Action Bar 2"] = true,
		["Action Bar 3"] = true,
		["Action Bar 4"] = true,
		["Action Bar 5"] = true,
		["Action Bar 6"] = true,
		["Action Bar 7"] = true,
		["Action Bar 8"] = true,
		["Stance Bar"] = true,
		["Pet Action Bar"] = true,
		["Link Action Bars"] = true,
		["Show while Skyriding"] = true,
		["Toggle mouseover for the main action bar"] = true,
		["Toggle mouseover for the bottom left action bar"] = true,
		["Toggle mouseover for the bottom right action bar"] = true,
		["Toggle mouseover for the right action bar"] = true,
		["Toggle mouseover for the left action bar"] = true,
		["Toggle mouseover for the action bar 6"] = true,
		["Toggle mouseover for the action bar 7"] = true,
		["Toggle mouseover for the action bar 8"] = true,
		["Toggle mouseover for the stance bar"] = true,
		["Toggle mouseover for the pet action bar"] = true,
		["Link all action bars to show/hide together"] = true,
		["Show main action bar while skyriding"] = true,
		["Fade-in delay"] = true,
		["Fade-out delay"] = true,
		["Fade-in duration"] = true,
		["Fade-out duration"] = true,
		["Delay before the action bar fades in"] = true,
		["Delay before the action bar fades out"] = true,
		["Duration of the fade-in animation"] = true,
		["Duration of the fade-out animation"] = true,
		["Fade-in transparency"] = true,
		["Fade-out transparency"] = true,
		["Transparency of the action bar when fully faded in"] = true,
		["Transparency of the action bar when fully faded out"] = true,
	},
	["deDE"] = {},
	["esES"] = {},
	["esMX"] = {},
	["frFR"] = {},
	["itIT"] = {},
	["koKR"] = {},
	["ptPT"] = {},
	["ruRU"] = {},
	["zhCN"] = {},
	["zhTW"] = {}

	-- The primary/default locale of your addon.
	-- * You should change this code to your default locale.
	-- * Note that you MUST include a full table for your primary/default locale!
}, "enUS")

-- Make it available addon-wide
addon.L = L
