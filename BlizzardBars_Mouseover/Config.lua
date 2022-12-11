-- Retrieve addon folder name, and our local, private namespace.
---@type string, table
local addonName, addon = ...

-- Lua API
-----------------------------------------------------------
-- Up-value any lua functions used here.
local math_abs = math.abs
local math_fmod = math.fmod


-- WoW API
-----------------------------------------------------------
-- Up-value any WoW functions used here.
---@type function
local InterfaceOptions_AddCategory = _G.InterfaceOptions_AddCategory

-- Your default settings.
-----------------------------------------------------------
-- Note that anything changed will be saved to disk when you reload the user
-- interface, or exit the game, and those saved changes will override your
-- defaults here.
-- * You should access saved settings by using `db[key]`
-- * Don't put frame handles or other widget references in here,
--   just strings, numbers, and booleans. Tables also work.
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
    FadeInDelay = 0,
    FadeInDuration = 0.1,
    FadeOutDelay = 0,
    FadeOutDuration = 0.1,
    AlphaMin = 0,
    AlphaMax = 1,
    MaxRefreshRate = 0.01,
}

--- Computed option values
addon.computedOptions = {
    FadeInAlphaStep = 0.1,
    FadeOutAlphaStep = 0.1,
}

--- Updates the existing DB when chaging option names.
--- Assume addon.db refences the saved variables table already.
function addon:MigrateDB()
    if (addon.db["pet_bar_ignore"] ~= nil) then
        addon.db.PetActionBar = addon.db.pet_bar_ignore
        addon.db.pet_bar_ignore = nil
    end
end

-- Addon API
-----------------------------------------------------------

--- Saves table to addon database
--- Remarks; it merges existing data with updated data and updates addon.db
---@param values table
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

--- Compute option values
function addon:ComputeValues()
    local alphaRange = math_abs(self.db["AlphaMax"] - self.db["AlphaMin"])
    self.computedOptions = {
        FadeInAlphaStep = alphaRange / (self.db["FadeInDuration"] / self.db["MaxRefreshRate"]),
        FadeOutAlphaStep = alphaRange / (self.db["FadeOutDuration"] / self.db["MaxRefreshRate"])
    }
end

--- Create checkbox for an action bar to active the mouseover settings
---@param parent any In-game option window
---@param name any Bar name
---@param title any Check box text
---@param x any Position on setting window x axis
---@param y any Position on setting window y axis
---@param default any
function addon:CreateButton(parent, name, title, x, y, default)
    if default == nil then default = true end
    local cb = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
    self = cb
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(title)
    if addon.db[name] ~= nil then
        default = addon.db[name]
    end
    cb:SetChecked(default)
    function self:OnCheckBoxClicked()
        addon.db[name] = self:GetChecked()
        addon:SaveToDB({
            configuration = addon.db
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
    local remain = math_fmod(value, 1)
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
    if addon.db[name] ~= nil then
        default = addon.db[name]
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
        addon.db[name] = roundValue
        addon:SaveToDB({
            configuration = addon.db
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
    panel.name = addon.shortName
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
