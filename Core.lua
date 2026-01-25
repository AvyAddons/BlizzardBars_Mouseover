---@class addon
local addon = select(2, ...)

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
local UnitPowerBarID = _G.UnitPowerBarID
---@type Frame
local SpellFlyout = _G["SpellFlyout"]

-- Constants
-----------------------------------------------------------
local MAIN_BAR = addon.MAIN_BAR

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
		local parent_name = parent ~= nil and parent:GetName() or ""
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
---@return boolean true if the bar should not be bypassed
function addon:CheckBypass(bar_name)
	-- if we're skyriding and this is the main bar, bypass the function
	local skyridingBypass = (self.skyriding and bar_name == MAIN_BAR)
	-- ad-hoc bypass of any given bar
	local adHocBypass = (self.bypass == bar_name or addon.db[bar_name] == false)

	return not (skyridingBypass or adHocBypass)
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
		if not addon.enabled then return end
		-- Always immediately start the fade-in, regardless of a running fade-out
		addon:CancelTimer(bar_name)
		addon:FadeBar("FadeIn", bar, bar_name)
	end)

	frame:HookScript("OnLeave", function()
		if not addon.enabled then return end
		local timer = addon.timers[bar_name]
		if (timer and not timer.cancelled and timer.name == "FadeIn") then
			timer.post_call = function() addon:FadeBar("FadeOut", bar, bar_name) end
		else
			addon:FadeBar("FadeOut", bar, bar_name)
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

	if self.db["LinkActionBars"] and self.db[bar_name] then
		for _, linked_bar_name in ipairs(self.bar_names) do
			self:CancelTimer(linked_bar_name) -- required to prevent flickering
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
	-- these secure hooks are automatically de-hooked on reload/relog, we can ignore OnDisable
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
--- @param frames boolean|nil If true, also show frame containers, micro menu, and aura frames
function addon:ShowBars(frames)
	self:CancelAllTimers()
	self:PauseCallbacks()
	for bar_name, bar in pairs(self.bars) do
		bar:SetAlpha(1)
		self:SetBlingRender(bar_name, true)
	end
	-- Also show frame containers, micro menu, and aura frames for toggle command
	if frames then
		self:ShowFrameContainers()
		self:ShowMicroMenu()
		self:ShowAuraFrames()
	end
end

--- Hide all bars
--- @param frames boolean|nil If true, also hide frame containers, micro menu, and aura frames
function addon:HideBars(frames)
	self:ResumeCallbacks()
	for bar_name, bar in pairs(self.bars) do
		self:ApplyOnBar(bar, bar_name)
		self:SetBlingRender(bar_name, false)
	end
	-- Also hide frame containers, micro menu, and aura frames
	if frames then
		self:HideFrameContainers()
		self:HideMicroMenu()
		self:HideAuraFrames()
	end
end

--- Toggle bar visibility and (un)register grid events
function addon:ToggleBars()
	if addon.enabled then
		self:ShowBars(true)
		self:UnregisterAllEvents()
	else
		self:HideBars(true)
		self:RegisterEvent("ACTIONBAR_SHOWGRID")
		self:RegisterEvent("ACTIONBAR_HIDEGRID")
		-- Skyriding events
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("UNIT_POWER_BAR_SHOW")
		self:RegisterEvent("UNIT_POWER_BAR_HIDE")
		-- Vehicle events
		self:RegisterEvent("UNIT_ENTERED_VEHICLE")
		self:RegisterEvent("UNIT_EXITED_VEHICLE")
		self:RegisterEvent("VEHICLE_UPDATE")
		self:RegisterEvent("TAXIMAP_CLOSED")
	end
end

--- Show main vehicle bar when skyriding
---@param event FrameEvent|nil Event name
---@param isInitialLogin boolean|nil Only defined when event is 'PLAYER_ENTERING_WORLD'
function addon:Skyriding(event, isInitialLogin)
	if (not addon.enabled or not addon.db.Skyriding) then
		return
	end

	if event == "PLAYER_ENTERING_WORLD" and isInitialLogin == true then
		C_Timer.After(2, addon.Skyriding)
		return
	end

	-- shamelessly copied from WeakAuras
	-- https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/Dragonriding.lua
	addon.skyriding = UnitPowerBarID("player") == 631
	if (addon.skyriding) then
		-- show main bar
		addon.bars[MAIN_BAR]:SetAlpha(1)
	else
		addon:ApplyOnBar(addon.bars[MAIN_BAR], MAIN_BAR)
	end
end

--- Special handling for vehicle buttons
---@param event FrameEvent The name of the event that fired.
function addon:Vehicle(event, ...)
	-- ignore when bypass disabled
	if (not self.enabled or not addon.db.Vehicle) then return end

	local vehicle = UnitInVehicle("player") or UnitOnTaxi("player") or false

	local button = _G["MainMenuBarVehicleLeaveButton"]
	local canExit = button:CanExitVehicle();

	if (vehicle) then
		-- show vehicle exit button
		if canExit then
			-- have to change parent, otherwise MainMenuBar will hide it
			button:SetParent(UIParent)
			button:Show()
		else
			-- hide vehicle exit button
			button:SetParent(addon.bars[MAIN_BAR])
			button:Hide()
		end
	else
		if not canExit then
			button:SetParent(addon.bars[MAIN_BAR])
			button:Hide()
		end
	end
end

function addon:HandleFlyoutShow()
	-- ignore when bypass enabled
	if (not self.enabled) then return end
	-- this returns nil if the parent isn't one of the bars we're hiding
	self.bypass = self:GetFlyoutParent()
	-- this happens when opening a flyout from the spellbook
	if (self.bypass == nil) then return end
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

-- Frame Container Functions (for bags bar)
-----------------------------------------------------------

--- Apply alpha to a given frame container
---@param container Frame
---@param container_name string
function addon:ApplyOnFrameContainer(container, container_name)
	if (container == nil) then return end
	if (container_name == nil or not self.db[container_name]) then
		container:SetAlpha(1)
		return
	end
	if (self.db[container_name]) then
		container:SetAlpha(addon.db.AlphaMin)
	else
		container:SetAlpha(1)
	end
end

--- Apply fade-in for frame container using timers
function addon:FadeInFrameContainerTimer(container_name)
	local alpha = addon.fades[container_name]
	if alpha == nil then
		alpha = addon.db["AlphaMin"]
		addon.fades[container_name] = alpha
	end
	local timer = addon:Timer(function()
		alpha = alpha + addon.db.FadeInAlphaStep
		if alpha >= addon.db["AlphaMax"] then
			addon:CancelTimer(container_name, true)
			alpha = addon.db["AlphaMax"]
		end
		addon.fades[container_name] = alpha
		-- Apply alpha to the container, not individual buttons
		self.containers[container_name]:SetAlpha(alpha)
	end, (addon.db["FadeInDelay"] or 0), addon.db["MaxRefreshRate"])
	return timer
end

--- Apply fade-out for frame container using timers
function addon:FadeOutFrameContainerTimer(container_name)
	local alpha = addon.fades[container_name]
	if alpha == nil then
		alpha = addon.db["AlphaMax"]
		addon.fades[container_name] = alpha
	end
	local timer = addon:Timer(function()
		alpha = alpha - addon.db.FadeOutAlphaStep
		if alpha <= addon.db["AlphaMin"] then
			addon:CancelTimer(container_name)
			alpha = addon.db["AlphaMin"]
		end
		addon.fades[container_name] = alpha
		-- Apply alpha to the container, not individual buttons
		self.containers[container_name]:SetAlpha(alpha)
	end, (addon.db["FadeOutDelay"] or 0), addon.db["MaxRefreshRate"])
	return timer
end

--- Fades frame container with a given transition
---@param transition "FadeIn"|"FadeOut"
---@param container_name string
function addon:FadeFrameContainer(transition, container_name)
	--@debug@
	assert(transition == "FadeIn" or transition == "FadeOut", "Unknown transition")
	--@end-debug@

	if self.db[container_name] then
		if transition == "FadeIn" then
			addon.timers[container_name] = addon:FadeInFrameContainerTimer(container_name)
		else
			addon.timers[container_name] = addon:FadeOutFrameContainerTimer(container_name)
		end
		addon.timers[container_name].name = transition
	end
end

--- Securely hooks into a frame's OnEnter and OnLeave to show/hide container.
---@param frame Frame Button frame on which to hook
---@param container Frame Container frame whose alpha should change
---@param container_name string Name of the container frame
function addon:SecureHookFrameContainer(frame, container, container_name)
	frame:HookScript("OnEnter", function()
		if not addon.enabled then return end
		-- Always immediately start the fade-in, regardless of a running fade-out
		addon:CancelTimer(container_name)
		addon:FadeFrameContainer("FadeIn", container_name)
	end)

	frame:HookScript("OnLeave", function()
		if not addon.enabled then return end
		local timer = addon.timers[container_name]
		if (timer and not timer.cancelled and timer.name == "FadeIn") then
			timer.post_call = function() addon:FadeFrameContainer("FadeOut", container_name) end
		else
			addon:FadeFrameContainer("FadeOut", container_name)
		end
	end)
end

--- Show all frame containers
function addon:ShowFrameContainers()
	for container_name, container in pairs(self.containers) do
		self:CancelTimer(container_name)
		-- Set container to full alpha
		container:SetAlpha(1)
	end
end

--- Hide all frame containers
function addon:HideFrameContainers()
	for container_name, container in pairs(self.containers) do
		self:ApplyOnFrameContainer(container, container_name)
	end
end

--- Hook frame containers (bags bar)
function addon:HookFrameContainers()
	if not self.db.BagsBar then return end
	for container_name, container in pairs(self.containers) do
		-- Apply initial alpha to container
		self:ApplyOnFrameContainer(container, container_name)
		-- Hook all buttons to trigger container fade
		for _, button in ipairs(self.frame_button_refs[container_name]) do
			self:SecureHookFrameContainer(button, container, container_name)
		end
	end
end

-- Micro Menu Functions
-----------------------------------------------------------

--- Apply alpha to all micro menu buttons
function addon:ApplyOnMicroMenu()
	if (not self.db.MicroButtons) then
		for _, button in ipairs(self.frame_button_refs.MicroButtons) do
			button:SetAlpha(1)
		end
		return
	end
	for _, button in ipairs(self.frame_button_refs.MicroButtons) do
		button:SetAlpha(addon.db.AlphaMin)
	end
end

--- Fades micro menu with a given transition
---@param transition "FadeIn"|"FadeOut"
function addon:FadeMicroMenu(transition)
	--@debug@
	assert(transition == "FadeIn" or transition == "FadeOut", "Unknown transition")
	--@end-debug@

	if self.db.MicroButtons then
		addon.timers["MicroButtons"] = addon[transition .. "MicroMenuTimer"](self)
		addon.timers["MicroButtons"].name = transition
	end
end

--- Apply fade-in for micro menu using timers
function addon:FadeInMicroMenuTimer()
	local alpha = addon.fades["MicroButtons"]
	if alpha == nil then
		alpha = addon.db["AlphaMin"]
		addon.fades["MicroButtons"] = alpha
	end
	local timer = addon:Timer(function()
		alpha = alpha + addon.db.FadeInAlphaStep
		if alpha >= addon.db["AlphaMax"] then
			addon:CancelTimer("MicroButtons", true)
			alpha = addon.db["AlphaMax"]
		end
		addon.fades["MicroButtons"] = alpha
		-- Apply alpha to all micro buttons individually
		for _, button in ipairs(self.frame_button_refs.MicroButtons) do
			button:SetAlpha(alpha)
		end
	end, (addon.db["FadeInDelay"] or 0), addon.db["MaxRefreshRate"])
	return timer
end

--- Apply fade-out for micro menu using timers
function addon:FadeOutMicroMenuTimer()
	local alpha = addon.fades["MicroButtons"]
	if alpha == nil then
		alpha = addon.db["AlphaMax"]
		addon.fades["MicroButtons"] = alpha
	end
	local timer = addon:Timer(function()
		alpha = alpha - addon.db.FadeOutAlphaStep
		if alpha <= addon.db["AlphaMin"] then
			addon:CancelTimer("MicroButtons")
			alpha = addon.db["AlphaMin"]
		end
		addon.fades["MicroButtons"] = alpha
		-- Apply alpha to all micro buttons individually
		for _, button in ipairs(self.frame_button_refs.MicroButtons) do
			button:SetAlpha(alpha)
		end
	end, (addon.db["FadeOutDelay"] or 0), addon.db["MaxRefreshRate"])
	return timer
end

--- Securely hooks into a frame's OnEnter and OnLeave to show/hide micro menu.
---@param frame Frame Button frame on which to hook
function addon:SecureHookMicroMenu(frame)
	frame:HookScript("OnEnter", function()
		if not addon.enabled then return end
		-- Always immediately start the fade-in, regardless of a running fade-out
		addon:CancelTimer("MicroButtons")
		addon:FadeMicroMenu("FadeIn")
	end)

	frame:HookScript("OnLeave", function()
		if not addon.enabled then return end
		local timer = addon.timers["MicroButtons"]
		if (timer and not timer.cancelled and timer.name == "FadeIn") then
			timer.post_call = function() addon:FadeMicroMenu("FadeOut") end
		else
			addon:FadeMicroMenu("FadeOut")
		end
	end)
end

--- Hook micro menu
function addon:HookMicroMenu()
	if not self.db.MicroButtons then return end
	-- Apply initial alpha to all micro buttons
	self:ApplyOnMicroMenu()
	-- Hook all micro buttons to trigger shared fade and handle OnEnable alpha resets
	for _, button in ipairs(self.frame_button_refs.MicroButtons) do
		self:SecureHookMicroMenu(button)
		-- Hook OnEnable to re-apply alpha when Blizzard enables the button
		-- MainMenuBarMicroButtonMixin:OnEnable() sets alpha to 1, which can be triggered
		-- from various events (PLAYER_ENTERING_WORLD, INITIAL_CLUBS_LOADED, etc.)
		-- without going through UpdateMicroButton()
		button:HookScript("OnEnable", function(btn)
			if addon.enabled and addon.db.MicroButtons then
				local alpha = addon.fades["MicroButtons"] or addon.db["AlphaMin"]
				btn:SetAlpha(alpha)
			end
		end)
	end
end

--- Show all micro menu buttons
function addon:ShowMicroMenu()
	self:CancelTimer("MicroButtons")
	for _, button in ipairs(self.frame_button_refs.MicroButtons) do
		button:SetAlpha(1)
	end
end

--- Hide all micro menu buttons
function addon:HideMicroMenu()
	self:ApplyOnMicroMenu()
end

--- Handle game menu showing - restore micro button alpha to 1 while menu is open
function addon:HandleGameMenuShow()
	-- When the Game Menu is shown, Blizzard reduces the micro buttons' alpha to 0.5
	-- The two exceptions are the Store and Main Menu buttons, which are set to alpha 1
	if addon.enabled and addon.db.MicroButtons then
		_G.StoreMicroButton:SetAlpha(1)
		_G.MainMenuMicroButton:SetAlpha(1)
	end
end

--- Handle game menu hiding - restore our micro button alpha
function addon:HandleGameMenuHide()
	-- Restore our micro button alpha after the menu closes and Blizzard resets to alpha 1
	if addon.enabled and addon.db.MicroButtons then
		addon:ApplyOnMicroMenu()
	end
end

-- Aura Frame Functions (for BuffFrame/DebuffFrame)
-----------------------------------------------------------

--- Apply alpha to an aura frame
---@param frame_name string Name of the aura frame ("BuffFrame" or "DebuffFrame")
function addon:ApplyOnAuraFrame(frame_name)
	local frame = self.aura_frames[frame_name]
	if (frame == nil) then return end
	if (self.db[frame_name]) then
		frame:SetAlpha(addon.db.AlphaMin)
	else
		frame:SetAlpha(1)
	end
end

--- Apply fade-in for aura frame using timers
---@param frame_name string Name of the aura frame
function addon:FadeInAuraFrameTimer(frame_name)
	local alpha = addon.fades[frame_name]
	if alpha == nil then
		alpha = addon.db["AlphaMin"]
		addon.fades[frame_name] = alpha
	end
	local timer = addon:Timer(function()
		alpha = alpha + addon.db.FadeInAlphaStep
		if alpha >= addon.db["AlphaMax"] then
			addon:CancelTimer(frame_name, true)
			alpha = addon.db["AlphaMax"]
		end
		addon.fades[frame_name] = alpha
		self.aura_frames[frame_name]:SetAlpha(alpha)
	end, (addon.db["FadeInDelay"] or 0), addon.db["MaxRefreshRate"])
	return timer
end

--- Apply fade-out for aura frame using timers
---@param frame_name string Name of the aura frame
function addon:FadeOutAuraFrameTimer(frame_name)
	local alpha = addon.fades[frame_name]
	if alpha == nil then
		alpha = addon.db["AlphaMax"]
		addon.fades[frame_name] = alpha
	end
	local timer = addon:Timer(function()
		alpha = alpha - addon.db.FadeOutAlphaStep
		if alpha <= addon.db["AlphaMin"] then
			addon:CancelTimer(frame_name)
			alpha = addon.db["AlphaMin"]
		end
		addon.fades[frame_name] = alpha
		self.aura_frames[frame_name]:SetAlpha(alpha)
	end, (addon.db["FadeOutDelay"] or 0), addon.db["MaxRefreshRate"])
	return timer
end

--- Fades aura frame with a given transition
---@param transition "FadeIn"|"FadeOut"
---@param frame_name string Name of the aura frame
function addon:FadeAuraFrame(transition, frame_name)
	--@debug@
	assert(transition == "FadeIn" or transition == "FadeOut", "Unknown transition")
	--@end-debug@

	if self.db[frame_name] then
		if transition == "FadeIn" then
			addon.timers[frame_name] = addon:FadeInAuraFrameTimer(frame_name)
		else
			addon.timers[frame_name] = addon:FadeOutAuraFrameTimer(frame_name)
		end
		addon.timers[frame_name].name = transition
	end
end

--- Securely hooks into an aura button's OnEnter and OnLeave to show/hide the aura frame.
---@param button Button Aura button frame on which to hook
---@param frame_name string Name of the aura frame ("BuffFrame" or "DebuffFrame")
function addon:SecureHookAuraButton(button, frame_name)
	button:HookScript("OnEnter", function()
		if not addon.enabled then return end
		addon:CancelTimer(frame_name)
		addon:FadeAuraFrame("FadeIn", frame_name)
	end)

	button:HookScript("OnLeave", function()
		if not addon.enabled then return end
		local timer = addon.timers[frame_name]
		if (timer and not timer.cancelled and timer.name == "FadeIn") then
			timer.post_call = function() addon:FadeAuraFrame("FadeOut", frame_name) end
		else
			addon:FadeAuraFrame("FadeOut", frame_name)
		end
	end)
end

--- Hook an aura frame and its buttons
---@param frame_name string Name of the aura frame ("BuffFrame" or "DebuffFrame")
function addon:HookAuraFrame(frame_name)
	if not self.db[frame_name] then return end
	self:ApplyOnAuraFrame(frame_name)
	local buttons = self.aura_buttons[frame_name]
	if buttons then
		for _, button in ipairs(buttons) do
			self:SecureHookAuraButton(button, frame_name)
		end
	end
	-- Also hook the CollapseAndExpandButton on BuffFrame
	local frame = self.aura_frames[frame_name]
	if frame and frame.CollapseAndExpandButton then
		self:SecureHookAuraButton(frame.CollapseAndExpandButton, frame_name)
	end
	-- Also hook ConsolidatedBuffs on BuffFrame
	if frame and frame.ConsolidatedBuffs then
		self:SecureHookAuraButton(frame.ConsolidatedBuffs, frame_name)
	end
end

--- Show all aura frames
function addon:ShowAuraFrames()
	for frame_name, frame in pairs(self.aura_frames) do
		self:CancelTimer(frame_name)
		frame:SetAlpha(1)
	end
end

--- Hide all aura frames
function addon:HideAuraFrames()
	for frame_name, _ in pairs(self.aura_frames) do
		self:ApplyOnAuraFrame(frame_name)
	end
end

--- Re-apply alpha to all UI elements if enabled
function addon:RefreshAlpha()
	if not addon.enabled then return end

	for bar_name, bar in pairs(self.bars) do
		self:ApplyOnBar(bar, bar_name)
	end

	for container_name, container in pairs(self.containers) do
		self:ApplyOnFrameContainer(container, container_name)
	end

	if self.db.MicroButtons then
		self:ApplyOnMicroMenu()
	end

	for frame_name, _ in pairs(self.aura_frames) do
		self:ApplyOnAuraFrame(frame_name)
	end
end
