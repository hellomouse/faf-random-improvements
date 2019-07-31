-- File adapted from allunits.lua from Name all the Things Mod
-- Yeah idk how to mod FAF yet

local isAutoSelection = false
local allUnits = {}
local lastFocusedArmy = 0

function selectAllUnits(update)
	if update then
		-- User.<global> UISelectionByCategory(expression, addToCurSel, inViewFrustum, nearestToMouse, mustBeIdle)
		UISelectionByCategory("ALLUNITS", false, false, false, false)
	end
	
	-- Add all units to allUnits table
	for _, unit in (GetSelectedUnits() or {}) do
		allUnits[unit:GetEntityId()] = unit
	end
end


function UpdateAllUnits()
	if GetFocusArmy() ~= lastFocusedArmy then
		Reset()
	else
		selectAllUnits(true)
	end

	-- Add focused (building or assisting)
	for _, unit in allUnits do
		if not unit:IsDead() and unit:GetFocus() and not unit:GetFocus():IsDead() then
			allUnits[unit:GetFocus():GetEntityId()] = unit:GetFocus()
		end
	end

	-- Remove dead
	for entityid, unit in allUnits do
		if unit:IsDead() then
			allUnits[entityid] = nil
		end
	end
end

function Reset()
	local currentlySelected = GetSelectedUnits() or {}
	isAutoSelection = true
	
	selectAllUnits(true)
	SelectUnits(currentlySelected)
	isAutoSelection = false
	lastFocusedArmy = GetFocusArmy()
end


function GetAllUnits()
	return allUnits
end

function IsAutoSelection()
	return isAutoSelection
end
