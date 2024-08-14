-- Retrieve addon folder name, and our local, private namespace.
---@type string
local addonName = ...
---@class addon
local addon = select(2, ...)
local L = addon.L

-- Lua API
-----------------------------------------------------------
-- Up-value any lua functions used here.
local math_abs = math.abs
local math_fmod = math.fmod

-- Your default settings.
-----------------------------------------------------------
-- Note that anything changed will be saved to disk when you reload the user
-- interface, or exit the game, and those saved changes will override your
-- defaults here.
-- * You should access saved settings by using `db[key]`
-- * Don't put frame handles or other widget references in here,
--   just strings, numbers, and booleans. Tables also work.
---@class db
addon.db = {
	-- Put your default settings here
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
	Skyriding = true,
	FadeInDelay = 0,
	FadeInDuration = 0.1,
	FadeOutDelay = 1,
	FadeOutDuration = 0.1,
	AlphaMin = 0,
	AlphaMax = 1,
	MaxRefreshRate = 0.01,
	FadeInAlphaStep = 0.1,
	FadeOutAlphaStep = 0.1,
}
addon.settings = {
	actionBarsProxy = {
		{
			name = L["Action Bar 1"],
			tooltip = L["Toggle mouseover for the main action bar"],
			variable = addon.shortName .. "_MainBar",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.True,
			GetValue = function()
				return addon.db.MainMenuBar
			end,
			SetValue = function(value)
				addon.db.MainMenuBar = value
				addon:ApplyOnBar(addon.bars["MainMenuBar"], "MainMenuBar")
			end,
		},
		{
			name = L["Action Bar 2"],
			tooltip = L["Toggle mouseover for the bottom left action bar"],
			variable = addon.shortName .. "_Bar2",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.True,
			GetValue = function()
				return addon.db.MultiBarBottomLeft
			end,
			SetValue = function(value)
				addon.db.MultiBarBottomLeft = value
				addon:ApplyOnBar(addon.bars["MultiBarBottomLeft"], "MultiBarBottomLeft")
			end,
		},
		{
			name = L["Action Bar 3"],
			tooltip = L["Toggle mouseover for the bottom right action bar"],
			variable = addon.shortName .. "_Bar3",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.True,
			GetValue = function()
				return addon.db.MultiBarBottomRight
			end,
			SetValue = function(value)
				addon.db.MultiBarBottomRight = value
				addon:ApplyOnBar(addon.bars["MultiBarBottomRight"], "MultiBarBottomRight")
			end,
		},
		{
			name = L["Action Bar 4"],
			tooltip = L["Toggle mouseover for the right action bar"],
			variable = addon.shortName .. "_Bar4",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.True,
			GetValue = function()
				return addon.db.MultiBarRight
			end,
			SetValue = function(value)
				addon.db.MultiBarRight = value
				addon:ApplyOnBar(addon.bars["MultiBarRight"], "MultiBarRight")
			end,
		},
		{
			name = L["Action Bar 5"],
			tooltip = L["Toggle mouseover for the left action bar"],
			variable = addon.shortName .. "_Bar5",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.True,
			GetValue = function()
				return addon.db.MultiBarLeft
			end,
			SetValue = function(value)
				addon.db.MultiBarLeft = value
				addon:ApplyOnBar(addon.bars["MultiBarLeft"], "MultiBarLeft")
			end,
		},
		{
			name = L["Action Bar 6"],
			tooltip = L["Toggle mouseover for the action bar 6"],
			variable = addon.shortName .. "_Bar6",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.True,
			GetValue = function()
				return addon.db.MultiBar5
			end,
			SetValue = function(value)
				addon.db.MultiBar5 = value
				addon:ApplyOnBar(addon.bars["MultiBar5"], "MultiBar5")
			end,
		},
		{
			name = L["Action Bar 7"],
			tooltip = L["Toggle mouseover for the action bar 7"],
			variable = addon.shortName .. "_Bar7",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.True,
			GetValue = function()
				return addon.db.MultiBar6
			end,
			SetValue = function(value)
				addon.db.MultiBar6 = value
				addon:ApplyOnBar(addon.bars["MultiBar6"], "MultiBar6")
			end,
		},
		{
			name = L["Action Bar 8"],
			tooltip = L["Toggle mouseover for the action bar 8"],
			variable = addon.shortName .. "_Bar8",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.True,
			GetValue = function()
				return addon.db.MultiBar7
			end,
			SetValue = function(value)
				addon.db.MultiBar7 = value
				addon:ApplyOnBar(addon.bars["MultiBar7"], "MultiBar7")
			end,
		},
		{
			name = L["Stance Bar"],
			tooltip = L["Toggle mouseover for the stance bar"],
			variable = addon.shortName .. "_StanceBar",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.True,
			GetValue = function()
				return addon.db.StanceBar
			end,
			SetValue = function(value)
				addon.db.StanceBar = value
				addon:ApplyOnBar(addon.bars["StanceBar"], "StanceBar")
			end,
		},
		{
			name = L["Pet Action Bar"],
			tooltip = L["Toggle mouseover for the pet action bar"],
			variable = addon.shortName .. "_PetBar",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.True,
			GetValue = function()
				return addon.db.PetActionBar
			end,
			SetValue = function(value)
				addon.db.PetActionBar = value
				addon:ApplyOnBar(addon.bars["PetActionBar"], "PetActionBar")
			end,
		},
	},
	actionBars = {
		{
			name = L["Link Action Bars"],
			tooltip = L["Link all action bars to show/hide together"],
			variable = addon.shortName .. "_Link",
			variableKey = "LinkActionBars",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.False,
		},
		{
			name = L["Show while Skyriding"],
			tooltip = L["Show main action bar while skyriding"],
			variable = addon.shortName .. "_Skyriding",
			variableKey = "Skyriding",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.True,
		}
	},
	fadeSliders = {
		{
			name = L["Fade-in delay"],
			tooltip = L["Delay before the action bar fades in"],
			variable = addon.shortName .. "_FadeInDelay",
			variableKey = "FadeInDelay",
			variableTbl = addon.db,
			type = Settings.VarType.Number,
			defaultValue = 0,
			minValue = 0,
			maxValue = 2,
			step = 0.1,
		},
		{
			name = L["Fade-in duration"],
			tooltip = L["Duration of the fade-in animation"],
			variable = addon.shortName .. "_FadeInDuration",
			variableKey = "FadeInDuration",
			variableTbl = addon.db,
			type = Settings.VarType.Number,
			defaultValue = 0.1,
			minValue = 0,
			maxValue = 2,
			step = 0.1,
		},
		{
			name = L["Fade-out delay"],
			tooltip = L["Delay before the action bar fades out"],
			variable = addon.shortName .. "_FadeOutDelay",
			variableKey = "FadeOutDelay",
			variableTbl = addon.db,
			type = Settings.VarType.Number,
			defaultValue = 1,
			minValue = 0,
			maxValue = 2,
			step = 0.1,
		},
		{
			name = L["Fade-out duration"],
			tooltip = L["Duration of the fade-out animation"],
			variable = addon.shortName .. "_FadeOutDuration",
			variableKey = "FadeOutDuration",
			variableTbl = addon.db,
			type = Settings.VarType.Number,
			defaultValue = 0.1,
			minValue = 0,
			maxValue = 2,
			step = 0.1,
		},
	},
	alphaSliders = {
		{
			name = L["Fade-in transparency"],
			tooltip = L["Transparency of the action bar when fully faded in"],
			variable = addon.shortName .. "_AlphaMin",
			variableKey = "AlphaMin",
			variableTbl = addon.db,
			type = Settings.VarType.Number,
			defaultValue = 0,
			minValue = 0,
			maxValue = 1,
			step = 0.01,
		},
		{
			name = L["Fade-out transparency"],
			tooltip = L["Transparency of the action bar when fully faded out"],
			variable = addon.shortName .. "_AlphaMax",
			variableKey = "AlphaMax",
			variableTbl = addon.db,
			type = Settings.VarType.Number,
			defaultValue = 1,
			minValue = 0,
			maxValue = 1,
			step = 0.01,
		},
	},
}

-- Addon API
-----------------------------------------------------------

--- Updates the existing DB when chaging option names.
--- Assume addon.db refences the saved variables table already.
function addon:MigrateDB()
	if (addon.db["pet_bar_ignore"] ~= nil) then
		addon.db.PetActionBar = addon.db.pet_bar_ignore
		addon.db.pet_bar_ignore = nil
	end
	if addon.db["Dragonriding"] ~= nil then
		addon.db.Skyriding = addon.db.Dragonriding
		addon.db.Dragonriding = nil
	end
end

--- Compute option values
function addon:ComputeValues()
	local alphaRange = math_abs(self.db.AlphaMax - self.db.AlphaMin)
	if (self.db.FadeInDuration == 0) then
		addon.db.FadeInAlphaStep = 1
	else
		addon.db.FadeInAlphaStep = alphaRange / (self.db.FadeInDuration / self.db.MaxRefreshRate)
	end
	if (self.db.FadeOutDuration == 0) then
		addon.db.FadeOutAlphaStep = 1
	else
		addon.db.FadeOutAlphaStep = alphaRange / (self.db.FadeOutDuration / self.db.MaxRefreshRate)
	end
end

--- Round a value to the nearest percentile
---@param value any Sliders values
function addon:RoundToNearestPercentile(value)
	local val = value * 100
	local remain = math_fmod(val, 1)
	if remain < 0.5 then
		val = val - remain
	elseif remain > 0.5 then
		val = val + 1 - remain
	end
	return val / 100
end

--- Create the in-game addon option window
function addon:CreateConfigPanel()
	local category, layout = Settings.RegisterVerticalLayoutCategory(addon.shortName)

	local function FormatSeconds(value)
		return string.format("%.1fs", value)
	end

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Action Bars"])); -- weird way to say "Add a header to the list"
	for _, s in ipairs(addon.settings.actionBarsProxy) do
		local setting = Settings.RegisterProxySetting(
			category, s.variable, s.type, s.name, s.defaultValue, s.GetValue, s.SetValue)
		Settings.CreateCheckbox(category, setting, s.tooltip)
	end
	for _, s in ipairs(addon.settings.actionBars) do
		-- the variable table must be the global saved variables table, the reference with addon.db does not work
		local setting = Settings.RegisterAddOnSetting(
			category, s.variable, s.variableKey, _G[addonName .. "_DB"], s.type, s.name, s.defaultValue)
		Settings.CreateCheckbox(category, setting, s.tooltip)
	end

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Fade Times"]));
	for _, s in ipairs(addon.settings.fadeSliders) do
		local GetValue = function() return addon.db[s.variableKey] end
		local SetValue = function(value)
			local roundValue = addon:RoundToNearestPercentile(value)
			if roundValue == addon.db[s.variableKey] then return end
			addon.db[s.variableKey] = value
			addon:ComputeValues()
		end
		local setting = Settings.RegisterProxySetting(
			category, s.variable, s.type, s.name, s.defaultValue, GetValue, SetValue)
		local options = Settings.CreateSliderOptions(s.minValue, s.maxValue, s.step);
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatSeconds);
		Settings.CreateSlider(category, setting, options, s.tooltip)
	end

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Transparency"]));
	for _, s in ipairs(addon.settings.alphaSliders) do
		local GetValue = function() return addon.db[s.variableKey] end
		local SetValue = function(value)
			local roundValue = addon:RoundToNearestPercentile(value)
			if roundValue == addon.db[s.variableKey] then return end
			addon.db[s.variableKey] = value
			addon:ComputeValues()
			for _, bar_name in pairs(addon.bar_names) do
				addon:ApplyOnBar(addon.bars[bar_name], bar_name)
			end
		end
		local setting = Settings.RegisterProxySetting(
			category, s.variable, s.type, s.name, s.defaultValue, GetValue, SetValue)
		local options = Settings.CreateSliderOptions(s.minValue, s.maxValue, s.step);
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage);
		Settings.CreateSlider(category, setting, options, s.tooltip)
	end

	Settings.RegisterAddOnCategory(category)
end

EventRegistry:RegisterFrameEventAndCallback("VARIABLES_LOADED", function()
	-- we sometimes change the options, hence the need to migrate tables
	addon:MigrateDB()
	addon:CreateConfigPanel()
end)
