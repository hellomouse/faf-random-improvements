local UIUtil = import('/lua/ui/uiutil.lua')
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Decal = import('/lua/user/userdecal.lua').UserDecal
local Prefs = import('/lua/user/prefs.lua')

local getUnits = import('/mods/Random Improvements/modules/allunits.lua').GetAllUnits
local UpdateAllUnits = import('/mods/Random Improvements/modules/allunits.lua').UpdateAllUnits

local rings = {}
local active = false
local showRangeTable = false
local ringRangeTable = {}
local ringRangeDefaults = {
	[1] = 30,
	[2] = 60,
	[3] = 90,
	[4] = 26,
	[5] = 50,
	[6] = 256,
	[7] = 115,
	[8] = 200,
	[9] = 100,
}

--category tester function, returns true if the bp includes the given category
function HasCategory(blueprint, category)
	if blueprint then
		if blueprint.Categories then
			for i, cat in blueprint.Categories do
				if cat == category then
					return true
				end
			end
		end
		return false
	end
end

--set the given index in the ring range table to the current selections range
function SetRingRange(rangeIndex)
	local selection = GetSelectedUnits()
	local bp = false
	if selection then
		bp = selection[1]:GetBlueprint()
	end
	local range = false
	if bp then
		if HasCategory(bp, 'ENGINEER') then
			if bp.Economy.MaxBuildDistance then
				ringRangeTable[rangeIndex] = bp.Economy.MaxBuildDistance + 2
			else
				ringRangeTable[rangeIndex] = 10
			end
		elseif bp.Weapon then
			if bp.Weapon[1].MaxRadius then
				ringRangeTable[rangeIndex] = bp.Weapon[1].MaxRadius
			end
		end
	end
	Prefs.SetToCurrentProfile("ringRangeSaves", ringRangeTable)
	Prefs.SavePreferences()
end

--show a ring with a specific range
function DisplayRing(rangeIndex)
	--if a ring is being shown already then just change its size to the new range
	if active then
		rings[active]:SetScale({2*ringRangeTable[rangeIndex] + 2, 0, 2*ringRangeTable[rangeIndex] + 2})
		rings[active]:SetPositionByScreen(GetMouseScreenPos())
	else
		--basically does table.insert, but allows me to track the index
		local firstFree = 1
		local foundFree = false
		while not foundFree do
			if rings[firstFree] then
				firstFree = firstFree + 1
			else
				active = firstFree
				foundFree = true
			end
		end
		rings[active] = Decal(GetFrame(0))
		rings[active]:SetTexture('/mods/range tester/textures/ring_green.dds')
		rings[active]:SetScale({math.floor(2.03*ringRangeTable[rangeIndex])+2, 0, math.floor(2.03*ringRangeTable[rangeIndex])+2})
		rings[active]:SetPositionByScreen(GetMouseScreenPos())
		--change worldview handleevent to stop normal click behaviour, and allow ring to be moved/placed/destroyed
		local worldview = import('/lua/ui/game/worldview.lua').viewLeft
		local oldHandleEvent = worldview.HandleEvent
		worldview.HandleEvent = function(self, event)
			rings[active]:SetPositionByScreen(GetMouseScreenPos())
			if event.Type == 'ButtonPress' then
				if event.Modifiers.Right then
					rings[active]:Destroy()
					rings[active] = nil
				--removed 10 second placement to make rings permanent. Just uncomment these 2 lines to get auto deletion back
				--else
				--	ForkThread(WaitThenDestroy, active)
				end
				active = false
				worldview.HandleEvent = oldHandleEvent
				return true
			end
		end
	end
end

--remove all placed range marker rings
function DestroyRings()
	if not active then
		for i, v in rings do
			v:Destroy()
		end
		rings = {}
	end
end

WaitThenDestroy = function(index)
	WaitSeconds(10)
	rings[index]:Destroy()
	rings[index] = false
end

--toggle show range of all selected units
function ToggleShowRanges()
	if showRangeTable then
		import('/lua/ui/game/gamemain.lua').RemoveBeatFunction(ShowRanges)
		for i, v in showRangeTable do
			if v.PrimaryWeaponRing then
				v.PrimaryWeaponRing:Destroy()
			end
			if v.BuildRangeRing then
				v.BuildRangeRing:Destroy()
			end
		end
		showRangeTable = false
	else
		showRangeTable = {}
		import('/lua/ui/game/gamemain.lua').AddBeatFunction(ShowRanges)
	end
end

--beat function, show all selected unit ranges
function ShowRanges()
	local worldview = import('/lua/ui/game/worldview.lua').viewLeft
	if showRangeTable then
		local selection = GetSelectedUnits()
		local selectedUnitInfo = {}
		if selection then
			for i, unit in selection do
				local id = unit:GetEntityId()
				selectedUnitInfo[id] = unit
			end
		end
		for id, unit in selectedUnitInfo do
			if not showRangeTable[id] then
				showRangeTable[id] = {}
				local bp = unit:GetBlueprint()
				if HasCategory(bp, 'ENGINEER') then
					showRangeTable[id].BuildRangeRing = Decal(GetFrame(0))
					showRangeTable[id].BuildRangeRing:SetTexture('/mods/range tester/textures/ring_orange.dds')
					if bp.Economy.MaxBuildDistance then
						showRangeTable[id].BuildRangeRing:SetScale({math.floor(2.03*(bp.Economy.MaxBuildDistance+2))+2, 0, math.floor(2.03*(bp.Economy.MaxBuildDistance+2))+2})
					else
						showRangeTable[id].BuildRangeRing:SetScale({22, 0, 22})
					end
				end
				if bp.Weapon then
					if bp.Weapon[1].MaxRadius then
						local range = bp.Weapon[1].MaxRadius
						showRangeTable[id].PrimaryWeaponRing = Decal(GetFrame(0))
						showRangeTable[id].PrimaryWeaponRing:SetTexture('/mods/range tester/textures/ring_red.dds')
						showRangeTable[id].PrimaryWeaponRing:SetScale({math.floor(2.03*range)+2, 0, math.floor(2.03*range)+2})
					end
				end
			end
			if showRangeTable[id] then
				local unitpos = unit:GetPosition()
				local temppos = worldview:Project(unitpos)
				local screenpos = {temppos[1] + worldview.Left(), temppos[2] + worldview.Top()}
				if showRangeTable[id].PrimaryWeaponRing then
					showRangeTable[id].PrimaryWeaponRing:SetPositionByScreen(screenpos)
				end
				if showRangeTable[id].BuildRangeRing then
					showRangeTable[id].BuildRangeRing:SetPositionByScreen(screenpos)
				end
			end
		end
		for id, overlay in showRangeTable do
			if not selectedUnitInfo[id] then
				if overlay.PrimaryWeaponRing then
					overlay.PrimaryWeaponRing:Destroy()
				end
				if overlay.BuildRangeRing then
					overlay.BuildRangeRing:Destroy()
				end
				showRangeTable[id] = nil
			end
		end
	end
end




local overlays = {}
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local ItemList = import('/lua/maui/itemlist.lua').ItemList
local Group = import('/lua/maui/group.lua').Group
local UIUtil = import('/lua/ui/uiutil.lua')



 function CreateNukeOverlay(unit)
	local overlay = Bitmap(GetFrame(0))
	local id = unit:GetEntityId()

	overlay:SetSolidColor('black')
	overlay.Width:Set(30)
	overlay.Height:Set(18)

	overlay:SetNeedsFrameUpdate(true)
	overlay.OnFrame = function(self, delta)
		if(not unit:IsDead()) then
			local worldView = import('/lua/ui/game/worldview.lua').viewLeft
			local pos = worldView:Project(unit:GetPosition())
			LayoutHelpers.AtLeftTopIn(overlay, worldView, pos.x - overlay.Width() / 2, pos.y - overlay.Height() / 2 + 1)
		else
			overlay.destroy = true
			overlay:Hide()
		end
	end

	overlay.id = unit:GetEntityId()
	overlay.destroy = false
	overlay.text = UIUtil.CreateText(overlay, '6', 11, UIUtil.bodyFont)
	overlay.text:SetColor('green')
	overlay.text:SetDropShadow(true)
	LayoutHelpers.AtCenterIn(overlay.text, overlay, 0, 0)

	return overlay
end

function UpdateNukeOverlay(k)
	local id = k:GetEntityId()
	local data = k:GetMissileInfo()
	local tech = 0
	
	-- This unit cannot make / store nukes --
	if data.nukeSiloMaxStorageCount == 0 then return end

	if(not overlays[id]) then
		overlays[id] = CreateNukeOverlay(k)
	end
	overlays[id].text:SetColor((data.nukeSiloStorageCount > 0 and 'white') or 'red')
	overlays[id].text:SetText(data.nukeSiloStorageCount .. " / " .. data.nukeSiloMaxStorageCount)
end


--
-- nukes are 
--uab2305
--ueb2305
--xsb2305
--urb2305
-- TODO keep previous selectino like idle engineers does
-- TODO fix idle engineers bug where it covers entire screen

function nukeOverlay()
	UpdateAllUnits()
	getUnits()
	
	local engineers = getUnits()
	for _, e in engineers do
	
		if string.find(""..e:GetUnitId(), "2305") then
			print("NUKE")
		end
		
		for i, v in e:GetMissileInfo() do LOG(i, v) end
		LOG(""..e:GetUnitId())
	
		
		if not e:IsDead() then
			UpdateNukeOverlay(e)
		end
	end
	for id, overlay in overlays do
		if not overlay or overlay.destroy then
			--print "Bye bye overlay 2"
			overlay:Destroy()
			overlays[id] = nil
		end
	end
end

function updateOverlay()
	while true do
		nukeOverlay()
		WaitSeconds(1)
	end
end

function Init()
	local ringKeyMap = {
	['Num0'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").ToggleShowRanges()'},
	['Num1'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").DisplayRing(1)'},
	['Num2'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").DisplayRing(2)'},
	['Num3'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").DisplayRing(3)'},
	['Num4'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").DisplayRing(4)'},
	['Num5'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").DisplayRing(5)'},
	['Num6'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").DisplayRing(6)'},
	['Num7'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").DisplayRing(7)'},
	['Num8'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").DisplayRing(8)'},
	['Num9'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").DisplayRing(9)'},
	['Ctrl-Num1'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").SetRingRange(1)'},
	['Ctrl-Num2'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").SetRingRange(2)'},
	['Ctrl-Num3'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").SetRingRange(3)'},
	['Ctrl-Num4'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").SetRingRange(4)'},
	['Ctrl-Num5'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").SetRingRange(5)'},
	['Ctrl-Num6'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").SetRingRange(6)'},
	['Ctrl-Num7'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").SetRingRange(7)'},
	['Ctrl-Num8'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").SetRingRange(8)'},
	['Ctrl-Num9'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").SetRingRange(9)'},
	['NumPeriod'] = {action =  'UI_Lua import("/mods/range tester/displayrings.lua").DestroyRings()'},
	}
	IN_AddKeyMapTable(ringKeyMap)
	ringRangeTable = Prefs.GetFromCurrentProfile("ringRangeSaves") or ringRangeDefaults
	
	ForkThread(updateOverlay)
end
