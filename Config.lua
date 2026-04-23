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
	MainActionBar = true,
	MultiBarBottomLeft = true,
	MultiBarBottomRight = true,
	MultiBarRight = true,
	MultiBarLeft = true,
	MultiBar5 = true,
	MultiBar6 = true,
	MultiBar7 = true,
	StanceBar = true,
	PetActionBar = true,
	BagsBar = true,
	MicroButtons = true,
	BuffFrame = false,
	DebuffFrame = false,
	LinkActionBars = false,
	Skyriding = true,
	Vehicle = true,
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
-- Snapshot the default values before addon.db is ever reassigned to a profile sub-table.
-- Used to fill in missing keys when a profile is loaded or newly created.
addon.defaults = CopyTable(addon.db)

-- Registered settings objects keyed by variableKey, used for in-place UI refresh on profile switch
addon.registeredSettings = {}

addon.settings = {
	actionBarsProxy = {
		{
			name = L["Action Bar 1"],
			tooltip = L["Toggle mouseover for the main action bar"],
			variable = addon.shortName .. "_MainBar",
			variableKey = "MainActionBar",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.True,
			GetValue = function()
				return addon.db.MainActionBar
			end,
			SetValue = function(value)
				addon.db.MainActionBar = value
				local barName = addon.MAIN_BAR
				addon:ApplyOnBar(addon.bars[barName], barName)
			end,
		},
		{
			name = L["Action Bar 2"],
			tooltip = L["Toggle mouseover for the bottom left action bar"],
			variable = addon.shortName .. "_Bar2",
			variableKey = "MultiBarBottomLeft",
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
			variableKey = "MultiBarBottomRight",
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
			variableKey = "MultiBarRight",
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
			variableKey = "MultiBarLeft",
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
			variableKey = "MultiBar5",
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
			variableKey = "MultiBar6",
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
			variableKey = "MultiBar7",
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
			variableKey = "StanceBar",
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
			variableKey = "PetActionBar",
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
			GetValue = function() return addon.db.LinkActionBars end,
			SetValue = function(value) addon.db.LinkActionBars = value end,
		},
		{
			name = L["Show while Skyriding"],
			tooltip = L["Show main action bar while skyriding. Requires a reload to take effect."],
			variable = addon.shortName .. "_Skyriding",
			variableKey = "Skyriding",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.True,
			GetValue = function() return addon.db.Skyriding end,
			SetValue = function(value) addon.db.Skyriding = value end,
		},
		{
			name = L["Show Vehicle Exit Button"],
			tooltip = L
				["Always show the vehicle exit button when mounted on a vehicle or taxi. Requires a reload to take effect."],
			variable = addon.shortName .. "_Vehicle",
			variableKey = "Vehicle",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.True,
			GetValue = function() return addon.db.Vehicle end,
			SetValue = function(value) addon.db.Vehicle = value end,
		}
	},
	bagsSettings = {
		{
			name = L["Bags Bar"],
			tooltip = L["Toggle mouseover for the bags bar"],
			variable = addon.shortName .. "_BagsBar",
			variableKey = "BagsBar",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.True,
			GetValue = function()
				return addon.db.BagsBar
			end,
			SetValue = function(value)
				addon.db.BagsBar = value
				if value then
					addon:HookFrameContainers()
					addon:ApplyOnFrameContainer(addon.containers["BagsBar"], "BagsBar")
				else
					addon:ShowFrameContainers()
				end
			end,
		}
	},
	microMenuSettings = {
		{
			name = L["Micro Buttons"],
			tooltip = L["Toggle mouseover for the micro menu buttons"],
			variable = addon.shortName .. "_MicroButtons",
			variableKey = "MicroButtons",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.True,
			GetValue = function()
				return addon.db.MicroButtons
			end,
			SetValue = function(value)
				addon.db.MicroButtons = value
				if value then
					addon:HookMicroMenu()
					addon:ApplyOnMicroMenu()
				else
					addon:ShowMicroMenu()
				end
			end,
		}
	},
	auraSettings = {
		{
			name = L["Buff Frame"],
			tooltip = L["Toggle mouseover for the buff frame"],
			variable = addon.shortName .. "_BuffFrame",
			variableKey = "BuffFrame",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.False,
			GetValue = function()
				return addon.db.BuffFrame
			end,
			SetValue = function(value)
				addon.db.BuffFrame = value
				if value then
					addon:HookAuraFrame("BuffFrame")
					addon:ApplyOnAuraFrame("BuffFrame")
				else
					addon.aura_frames["BuffFrame"]:SetAlpha(1)
				end
			end,
		},
		{
			name = L["Debuff Frame"],
			tooltip = L["Toggle mouseover for the debuff frame"],
			variable = addon.shortName .. "_DebuffFrame",
			variableKey = "DebuffFrame",
			type = Settings.VarType.Boolean,
			defaultValue = Settings.Default.False,
			GetValue = function()
				return addon.db.DebuffFrame
			end,
			SetValue = function(value)
				addon.db.DebuffFrame = value
				if value then
					addon:HookAuraFrame("DebuffFrame")
					addon:ApplyOnAuraFrame("DebuffFrame")
				else
					addon.aura_frames["DebuffFrame"]:SetAlpha(1)
				end
			end,
		},
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
	if addon.db["MainMenuBar"] ~= nil and addon.db["MainActionBar"] == nil then
		self:Debug("Migrating MainActionBar")
		addon.db.MainActionBar = addon.db.MainMenuBar
		addon.db.MainMenuBar = nil
	elseif addon.db["MainMenuBar"] ~= nil then
		addon.db.MainMenuBar = nil
	end
end

--- Apply the active profile to all bars and UI elements
function addon:ApplyProfile()
	self:ComputeValues()
	for bar_name, bar in pairs(self.bars) do
		self:ApplyOnBar(bar, bar_name)
	end
	for container_name, container in pairs(self.containers) do
		self:ApplyOnFrameContainer(container, container_name)
	end
	self:ApplyOnMicroMenu()
	for frame_name in pairs(self.aura_frames) do
		self:ApplyOnAuraFrame(frame_name)
	end
end

--- Refreshes all registered setting widgets in-place to reflect the active profile.
--- Must be called after addon.db is reassigned to a new profile sub-table.
---
--- Uses setting:SetValue() (the method on the setting object) rather than Settings.SetValue().
--- Settings.SetValue() calls our SetValue callback and writes to db — the wrong direction.
--- setting:SetValue() fires the internal changed event so the widget redraws without a side-effect.
function addon:RefreshSettingsUI()
	for variableKey, setting in pairs(self.registeredSettings) do
		local val = self.db[variableKey]
		if val ~= nil then setting:SetValue(val) end
	end
	if self.profileDropdownSetting then
		self.profileDropdownSetting:SetValue(self.sv.activeProfile or "Default")
	end
	if self.charProfileDropdownSetting then
		local charProfile = self.charKey and self.sv.characterProfiles[self.charKey]
		self.charProfileDropdownSetting:SetValue(charProfile or "(Use global default)")
	end
end

--- Returns a sorted list of profile names
---@return string[]
function addon:GetProfileList()
	local list = {}
	for name in pairs(self.sv.profiles) do
		list[#list + 1] = name
	end
	table.sort(list)
	return list
end

--- Creates a new profile as a copy of the current one and assigns it to the current character.
---@param name string
function addon:CreateProfile(name)
	if self.sv.profiles[name] then return end
	local newProfile = {}
	for key, val in pairs(self.db) do
		newProfile[key] = val
	end
	self.sv.profiles[name] = newProfile
	self:SetCharacterProfile(name)
end

--- Resolves which profile should be active for the current character and sets addon.db.
--- Character override (sv.characterProfiles) takes priority over the global default (sv.activeProfile).
--- Stale assignments pointing at deleted profiles are healed back to "Default".
function addon:ResolveCharacterProfile()
	local sv = self.sv
	local resolvedName
	if self.charKey then
		local charProfile = sv.characterProfiles[self.charKey]
		if charProfile then
			if type(sv.profiles[charProfile]) == "table" then
				resolvedName = charProfile
			else
				-- Profile was deleted; clear the stale assignment
				sv.characterProfiles[self.charKey] = nil
			end
		end
	end
	if not resolvedName then
		resolvedName = sv.activeProfile or "Default"
		if type(sv.profiles[resolvedName]) ~= "table" then
			resolvedName = "Default"
			sv.activeProfile = "Default"
		end
	end
	local profile = sv.profiles[resolvedName]
	for key, val in pairs(self.defaults) do
		if profile[key] == nil then profile[key] = val end
	end
	self.db = profile
end

--- Assigns a profile to the current character and switches to it.
--- Writes sv.characterProfiles[charKey] and reassigns addon.db.
---@param profileName string
function addon:SetCharacterProfile(profileName)
	if not self.sv.profiles[profileName] then return end
	if self.charKey then
		self.sv.characterProfiles[self.charKey] = profileName
	end
	local profile = self.sv.profiles[profileName]
	for key, val in pairs(self.defaults) do
		if profile[key] == nil then profile[key] = val end
	end
	self.db = profile
	self:ApplyProfile()
	if self.configInitialized then
		self:RefreshSettingsUI()
	end
end

--- Sets the global default profile used by characters with no specific assignment.
--- Writes sv.activeProfile. Updates addon.db only when the current character has no override.
---@param profileName string
function addon:SetGlobalDefaultProfile(profileName)
	if not self.sv.profiles[profileName] then return end
	self.sv.activeProfile = profileName
	local hasOverride = self.charKey and self.sv.characterProfiles[self.charKey] ~= nil
	if not hasOverride then
		local profile = self.sv.profiles[profileName]
		for key, val in pairs(self.defaults) do
			if profile[key] == nil then profile[key] = val end
		end
		self.db = profile
		self:ApplyProfile()
	end
	if self.configInitialized then
		self:RefreshSettingsUI()
	end
end

--- Deletes a profile, re-resolves the active profile for the current character.
---@param name string
function addon:DeleteProfile(name)
	if name == "Default" then return end
	if not self.sv.profiles[name] then return end
	-- Clear any character assignments pointing to this profile
	for key, profileName in pairs(self.sv.characterProfiles) do
		if profileName == name then
			self.sv.characterProfiles[key] = nil
		end
	end
	self.sv.profiles[name] = nil
	-- If it was the global default, fall back to Default
	if self.sv.activeProfile == name then
		self.sv.activeProfile = "Default"
	end
	self:ResolveCharacterProfile()
	self:ApplyProfile()
	if self.configInitialized then
		self:RefreshSettingsUI()
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

--- Helper to register a setting and store it for in-place UI refresh
---@param category any
---@param s table setting definition with variable, variableKey, type, name, defaultValue, GetValue, SetValue
---@return any setting
local function RegisterAndStore(category, s)
	local setting = Settings.RegisterProxySetting(
		category, s.variable, s.type, s.name, s.defaultValue, s.GetValue, s.SetValue)
	if s.variableKey then
		addon.registeredSettings[s.variableKey] = setting
	end
	return setting
end

--- Create the in-game addon option window
function addon:CreateConfigPanel()
	local category, layout = Settings.RegisterVerticalLayoutCategory(addon.shortName)
	addon.category = category:GetID()

	local function FormatSeconds(value)
		return string.format("%.1fs", value)
	end

	-- Profiles section
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Profiles"]))

	-- Per-character profile dropdown
	local charProfileGetValue = function()
		local charProfile = addon.charKey and addon.sv.characterProfiles[addon.charKey]
		return charProfile or "(Use global default)"
	end
	local charProfileSetValue = function(value)
		if value == "(Use global default)" then
			if addon.charKey then
				addon.sv.characterProfiles[addon.charKey] = nil
			end
			addon:ResolveCharacterProfile()
			addon:ApplyProfile()
			if addon.configInitialized then addon:RefreshSettingsUI() end
		else
			addon:SetCharacterProfile(value)
		end
	end
	local charProfileSetting = Settings.RegisterProxySetting(
		category, addon.shortName .. "_CharProfile", Settings.VarType.String,
		L["Character Profile"], "(Use global default)", charProfileGetValue, charProfileSetValue)
	addon.charProfileDropdownSetting = charProfileSetting
	local function GetCharProfileOptions()
		local container = Settings.CreateControlTextContainer()
		container:Add("(Use global default)", L["(Use global default)"])
		for _, name in ipairs(addon:GetProfileList()) do
			container:Add(name, name)
		end
		return container:GetData()
	end
	Settings.CreateDropdown(category, charProfileSetting, GetCharProfileOptions, L["Set which profile this character uses"])

	-- Global default dropdown
	local globalProfileGetValue = function()
		return addon.sv.activeProfile or "Default"
	end
	local globalProfileSetValue = function(value)
		addon:SetGlobalDefaultProfile(value)
	end
	local globalProfileSetting = Settings.RegisterProxySetting(
		category, addon.shortName .. "_GlobalProfile", Settings.VarType.String,
		L["Global Default Profile"], "Default", globalProfileGetValue, globalProfileSetValue)
	addon.profileDropdownSetting = globalProfileSetting
	local function GetGlobalProfileOptions()
		local container = Settings.CreateControlTextContainer()
		for _, name in ipairs(addon:GetProfileList()) do
			container:Add(name, name)
		end
		return container:GetData()
	end
	Settings.CreateDropdown(category, globalProfileSetting, GetGlobalProfileOptions, L["Set the default profile for characters with no specific assignment"])

	layout:AddInitializer(CreateSettingsButtonInitializer(
		L["New Profile"],
		L["New Profile"],
		function()
			StaticPopup_ShowCustomGenericInputBox({
				text = L["Enter a name for the new profile:"],
				acceptText = L["Create"],
				maxLetters = 32,
				callback = function(name)
					if name and name ~= "" then addon:CreateProfile(name) end
				end,
			})
		end,
		L["Create a new profile as a copy of the current one"],
		false
	))

	-- Delete profile button — clicking on Default silently does nothing
	layout:AddInitializer(CreateSettingsButtonInitializer(
		L["Delete Profile"],
		L["Delete Profile"],
		function()
			local charProfile = addon.charKey and addon.sv.characterProfiles[addon.charKey]
			local current = charProfile or addon.sv.activeProfile or "Default"
			if current == "Default" then return end
			StaticPopup_ShowCustomGenericConfirmation({
				text = string.format(L["Delete profile \"%s\"?"], current),
				acceptText = DELETE,
				cancelText = CANCEL,
				callback = function()
					addon:DeleteProfile(current)
				end,
			})
		end,
		L["Delete the current profile (not available for Default)"],
		false
	))

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Action Bars"]))
	for _, s in ipairs(addon.settings.actionBarsProxy) do
		local setting = RegisterAndStore(category, s)
		Settings.CreateCheckbox(category, setting, s.tooltip)
	end
	for _, s in ipairs(addon.settings.actionBars) do
		local setting = RegisterAndStore(category, s)
		Settings.CreateCheckbox(category, setting, s.tooltip)
	end

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Bags"]));
	for _, s in ipairs(addon.settings.bagsSettings) do
		local setting = RegisterAndStore(category, s)
		Settings.CreateCheckbox(category, setting, s.tooltip)
	end

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Micro Menu"]));
	for _, s in ipairs(addon.settings.microMenuSettings) do
		local setting = RegisterAndStore(category, s)
		Settings.CreateCheckbox(category, setting, s.tooltip)
	end

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Auras"]));
	for _, s in ipairs(addon.settings.auraSettings) do
		local setting = RegisterAndStore(category, s)
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
		addon.registeredSettings[s.variableKey] = setting
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
		addon.registeredSettings[s.variableKey] = setting
		local options = Settings.CreateSliderOptions(s.minValue, s.maxValue, s.step);
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage);
		Settings.CreateSlider(category, setting, options, s.tooltip)
	end

	Settings.RegisterAddOnCategory(category)
end

--- Called from Environment.lua after ADDON_LOADED to ensure addon.db is ready
function addon:InitializeConfig()
	-- we sometimes change the options, hence the need to migrate tables
	self:MigrateDB()
	self:CreateConfigPanel()
	self.configInitialized = true
end
