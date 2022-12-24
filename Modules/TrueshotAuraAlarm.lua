local store
local frame = nil
local UPDATE_DELAY = 15
local DEFAULT_ICON_SIZE = 48
local MINUTES_LEFT_WARNING = 5

-- ************ State ************
local aura = (function()
	local knowsAura, isActive, lastUpdate, timeLeft = false, false, 1800, 0
	local updateState = function()
		knowsAura = Quiver_Lib_Spellbook_GetIsSpellLearned("Trueshot Aura")
			or not Quiver_Store.IsLockedFrames
		lastUpdate, timeLeft, isActive = 0, 0, false
		-- This seems to check debuffs as well (tested with deserter)
		-- Turtle supports 24 buffs and 24 debuffs, so up to 48 slots
		for i=0,47 do
			local texture = GetPlayerBuffTexture(i)
			if texture == QUIVER.Icon.Trueshot then
				isActive = true
				timeLeft = GetPlayerBuffTimeLeft(i)
				return
			end
		end
	end
	return {
		ShouldUpdate = function(elapsed)
			lastUpdate = lastUpdate + elapsed
			return knowsAura and lastUpdate > UPDATE_DELAY
		end,
		UpdateUI = function()
			updateState()
			if not Quiver_Store.IsLockedFrames or knowsAura and not isActive then
				frame.Icon:SetAlpha(0.75)
				frame:SetBackdropColor(0.8, 0, 0, 0.8)
			elseif knowsAura and isActive and timeLeft < MINUTES_LEFT_WARNING * 60 then
				frame.Icon:SetAlpha(0.4)
				frame:SetBackdropColor(0, 0, 0, 0.1)
			else
				frame.Icon:SetAlpha(0.0)
				frame:SetBackdropColor(0, 0, 0, 0)
			end
		end,
	}
end)()

-- ************ UI ************
local createUI = function()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetFrameStrata("HIGH")
	f:SetBackdrop({ bgFile = "Interface/BUTTONS/WHITE8X8", tile = false })

	f.Icon = CreateFrame("Frame", nil, f)
	f.Icon:SetWidth(store.FrameMeta.W)
	f.Icon:SetHeight(store.FrameMeta.H)
	f.Icon:SetPoint("Center", 0, 0)
	f.Icon:SetBackdrop({ bgFile = QUIVER.Icon.Trueshot, tile = false })

	local resizeIcon = function()
		f.Icon:SetWidth(f:GetWidth())
		f.Icon:SetHeight(f:GetHeight())
		f.Icon:SetPoint("Center", 0, 0)
	end
	Quiver_Event_FrameLock_MakeMoveable(f, store.FrameMeta)
	Quiver_Event_FrameLock_MakeResizeable(f, store.FrameMeta, {
		GripMargin=0,
		OnResizeDrag=resizeIcon,
		OnResizeEnd=resizeIcon,
	})
	return f
end

-- ************ Event Handlers ************
local EVENTS = {
	"PLAYER_AURAS_CHANGED",
	"SPELLS_CHANGED",-- Open or click thru spellbook, learn/unlearn spell
}
local handleEvent = function()
	if event == "SPELLS_CHANGED" and arg1 ~= "LeftButton"
		or event == "PLAYER_AURAS_CHANGED"
	then
		aura.UpdateUI()
	end
end

-- ************ Initialization ************
local onEnable = function()
	if frame == nil then frame = createUI() end
	frame:SetScript("OnEvent", handleEvent)
	frame:SetScript("OnUpdate", function()
		if aura.ShouldUpdate(arg1) then aura.UpdateUI() end
	end)
	for _k, e in EVENTS do frame:RegisterEvent(e) end
	frame:Show()
	aura.UpdateUI()
end
local onDisable = function()
	frame:Hide()
	for _k, e in EVENTS do frame:UnregisterEvent(e) end
end

Quiver_Module_TrueshotAuraAlarm = {
	Id = "TrueshotAuraAlarm",
	OnInitFrames = function(options)
		if options.IsReset then store.FrameMeta = nil end
		store.FrameMeta = Quiver_Event_FrameLock_RestoreSize(store.FrameMeta, {
			w=DEFAULT_ICON_SIZE,
			h=DEFAULT_ICON_SIZE,
			dx=DEFAULT_ICON_SIZE * -0.5,
			dy=DEFAULT_ICON_SIZE * -0.5,
		})
		if options.IsReset and frame ~= nil then
			frame:SetPoint("TopLeft", store.FrameMeta.X, store.FrameMeta.Y)
		end
	end,
	OnEnable = onEnable,
	OnDisable = onDisable,
	OnInterfaceLock = function() aura.UpdateUI() end,
	OnInterfaceUnlock = function() aura.UpdateUI() end,
	OnSavedVariablesRestore = function(savedVariables)
		store = savedVariables
		store.FrameMeta = store.FrameMeta or {}
	end,
	OnSavedVariablesPersist = function() return store end,
}