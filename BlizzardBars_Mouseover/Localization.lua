-- Retrieve addon folder name, and our local, private namespace.
---@type string, table
local addonName, addon = ...

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
    local gameLocale = GetLocale() -- The locale currently used by the game client.
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
