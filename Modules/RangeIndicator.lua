local MODULE_ID = "RangeIndicator"
local store = nil
local frame = nil

local println = Quiver_Lib_Print_Factory(MODULE_ID)
local fontString = nil

local setFramePosition = function(f, s)
	s.FrameMeta = Quiver_Event_FrameLock_RestoreSize(s.FrameMeta, {
		w=190, h=35, dx=190 * -0.5, dy=-183,
	})
	f:SetWidth(s.FrameMeta.W)
	f:SetHeight(s.FrameMeta.H)
	f:SetPoint("TopLeft", s.FrameMeta.X, s.FrameMeta.Y)
end

local createUI = function()
	local f = CreateFrame("Frame", nil, UIParent)
	if Quiver_Store.IsLockedFrames then f:Hide() end

	setFramePosition(f, store)
	Quiver_Event_FrameLock_MakeMoveable(f, store.FrameMeta)
	Quiver_Event_FrameLock_MakeResizeable(f, store.FrameMeta, { GripMargin=4 })

	f:SetFrameStrata("LOW")
	f:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true,
		tileSize = 8,
		edgeSize = 16,
		insets = { left=4, right=4, top=4, bottom=4 },
	})
	f:SetBackdropColor(0, 0, 0, 0.6)
	f:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

	local fs = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fs:SetAllPoints(f)
	fs:SetJustifyH("Center")
	fs:SetJustifyV("Center")
	fs:SetText("Range Indicator")
	fs:SetTextColor(1, 1, 1)

	return f, fs
end

-- IsSpellInRange isn't in 1.12 API, so we need to check action bar
local checkActionBarDistance = function(spellName)
	local slot = Quiver_Lib_ActionBar_FindSlot(println, spellName)
	return IsActionInRange(slot) == 1
end
local checkDistance = {
	-- High Performance Builtin
	-- https://wowwiki-archive.fandom.com/wiki/API_CheckInteractDistance
	Inspect=function() return CheckInteractDistance("target", 1) end,-- 28 yards
	Trade=function() return CheckInteractDistance("target", 2) end,-- 11.11 yards
	Duel=function() return CheckInteractDistance("target", 3) end,-- 9.9 yards
	Follow=function() return CheckInteractDistance("target", 4) end,-- 28 yards
	-- Using Action Bars
	Melee=function() return checkActionBarDistance(QUIVER_T.Spellbook.Wing_Clip) end,-- 5 yards
	Mark=function() return checkActionBarDistance(QUIVER_T.Spellbook.Hunters_Mark) end,-- 100 yards
	Ranged=function() return checkActionBarDistance(QUIVER_T.Spellbook.Auto_Shot) end,-- 30-36 yards (talents)
	Scare=function() return checkActionBarDistance(QUIVER_T.Spellbook.Scare_Beast) end,-- 10 yards
	Scatter=function() return checkActionBarDistance(QUIVER_T.Spellbook.Scatter_Shot) end,-- 15 yards
}

local render = function(color, text)
	fontString:SetText(text)
	local r, g, b, a = unpack(color)
	frame:SetBackdropColor(r, g, b, a)
	frame:SetBackdropBorderColor(r, g, b, a)
	if not Quiver_Store.IsLockedFrames then
		frame.QuiverGripHandle:GetNormalTexture():SetVertexColor(r, g, b)
		frame.QuiverGripHandle:GetHighlightTexture():SetVertexColor(r+0.3, g-0.1, b+0.3)
	end
end

-- ************ Event Handlers ************
local handleUpdate = function()
	if checkDistance.Melee() then
		render(store.ColorMelee, "Melee Range")
	elseif checkDistance.Ranged() then
		if UnitCreatureType("target") == "Beast" and checkDistance.Scare() then
			render(store.ColorScareBeast, "Scare Beast")
		elseif checkDistance.Scatter() then
			render(store.ColorScatterShot, "Scatter Range")
		elseif checkDistance.Follow() then
			render(store.ColorShort, "Short Range")
		else
			render(store.ColorLong, "Long Range")
		end
	elseif checkDistance.Follow() then
		render(store.ColorDeadZone, "Dead Zone")
	elseif checkDistance.Mark() then
		render(store.ColorMark, "Mark Range")
	else
		render(store.ColorTooFar, "Out of Range")
	end
end

local handleEvent = function()
	if UnitExists("target")
		and (not UnitIsDead("target"))
		and UnitCanAttack("player", "target")
	then
		frame:Show()
	elseif Quiver_Store.IsLockedFrames
		then frame:Hide()
	end
end

-- ************ Initialization ************
local EVENTS = { "PLAYER_TARGET_CHANGED", "UNIT_FACTION" }
local onEnable = function()
	if frame == nil then frame, fontString = createUI() end
	frame:SetScript("OnEvent", handleEvent)
	frame:SetScript("OnUpdate", handleUpdate)
	for _k, e in EVENTS do frame:RegisterEvent(e) end
	if Quiver_Store.IsLockedFrames then handleEvent() else frame:Show() end
end

local onDisable = function()
	frame:Hide()
	for _k, e in EVENTS do frame:UnregisterEvent(e) end
end

Quiver_Module_RangeIndicator = {
	Id = MODULE_ID,
	Name = QUIVER_T.ModuleName[MODULE_ID],
	OnEnable = onEnable,
	OnDisable = onDisable,
	OnInterfaceLock = function() handleEvent() end,
	OnInterfaceUnlock = function() frame:Show() end,
	OnResetFrames = function()
		store.FrameMeta = nil
		if frame then setFramePosition(frame, store) end
	end,
	OnSavedVariablesRestore = function(savedVariables)
		store = savedVariables
		store.FrameMeta = store.FrameMeta or {}
		store.ColorMelee = store.ColorMelee or QUIVER.ColorDefault.Range.Melee
		store.ColorDeadZone = store.ColorDeadZone or QUIVER.ColorDefault.Range.DeadZone
		store.ColorScareBeast = store.ColorScareBeast or QUIVER.ColorDefault.Range.ScareBeast
		store.ColorScatterShot = store.ColorScatterShot or QUIVER.ColorDefault.Range.ScatterShot
		store.ColorShort = store.ColorShort or QUIVER.ColorDefault.Range.Short
		store.ColorLong = store.ColorLong or QUIVER.ColorDefault.Range.Long
		store.ColorMark = store.ColorMark or QUIVER.ColorDefault.Range.Mark
		store.ColorTooFar = store.ColorTooFar or QUIVER.ColorDefault.Range.TooFar
	end,
	OnSavedVariablesPersist = function() return store end,
}
