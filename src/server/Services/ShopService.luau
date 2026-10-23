--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gear = require(ReplicatedStorage.Shared.Logic.Gear)
local Actions = require(script.Parent.Actions)
local CombatService = require(script.Parent.CombatService)

local ShopService = {}

local function validKind(kind: any): boolean
	return kind == "Weapon" or kind == "Armor"
end

function ShopService.init()
	Actions.bind("BuyItem", function(player, data, kind, id)
		if not validKind(kind) or type(id) ~= "string" then
			return false, "Invalid item"
		end
		local ok, message = Gear.buy(data, kind, id)
		if ok then
			task.defer(CombatService.refreshLoadout, player)
		end
		return ok, message
	end)

	Actions.bind("EquipItem", function(player, data, kind, id)
		if not validKind(kind) or type(id) ~= "string" then
			return false, "Invalid item"
		end
		local ok, message = Gear.equip(data, kind, id)
		if ok then
			task.defer(CombatService.refreshLoadout, player)
		end
		return ok, message
	end)

	Actions.bind("UnequipArmor", function(player, data)
		if data.EquippedArmor == "" then
			return false, "No armor equipped"
		end
		data.EquippedArmor = ""
		task.defer(CombatService.refreshLoadout, player)
		return true, "Armor removed"
	end)
end

return ShopService
