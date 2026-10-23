--!strict
local Config = require(script.Parent.Parent.Config)
local ArmorConfig = require(script.Parent.Parent.Config.Armor)
local WeaponsConfig = require(script.Parent.Parent.Config.Weapons)
local Types = require(script.Parent.Types)

export type Kind = "Weapon" | "Armor"

local Gear = {}

function Gear.getWeapon(id: string): WeaponsConfig.Weapon?
	for _, weapon in Config.Weapons do
		if weapon.Id == id then
			return weapon
		end
	end
	return nil
end

function Gear.getArmor(id: string): ArmorConfig.Armor?
	for _, armor in Config.Armor do
		if armor.Id == id then
			return armor
		end
	end
	return nil
end

local function lookup(kind: string, id: string): (string?, number?, number?)
	if kind == "Weapon" then
		local weapon = Gear.getWeapon(id)
		if weapon then
			return weapon.Name, weapon.Price, weapon.LevelRequired
		end
	elseif kind == "Armor" then
		local armor = Gear.getArmor(id)
		if armor then
			return armor.Name, armor.Price, armor.LevelRequired
		end
	end
	return nil, nil, nil
end

local function ownedTable(data: Types.PlayerData, kind: string): { [string]: boolean }
	return if kind == "Weapon" then data.OwnedWeapons else data.OwnedArmor
end

-- Buying an item also equips it.
function Gear.buy(data: Types.PlayerData, kind: string, id: string): (boolean, string)
	local name, price, levelRequired = lookup(kind, id)
	if name == nil or price == nil or levelRequired == nil then
		return false, "Unknown item"
	end
	local owned = ownedTable(data, kind)
	if owned[id] then
		return false, "You already own " .. name
	end
	if data.Level < levelRequired then
		return false, `Requires level {levelRequired}`
	end
	if data.Coins < price then
		return false, "Not enough coins"
	end
	data.Coins -= price
	owned[id] = true
	Gear.equip(data, kind, id)
	return true, "Bought " .. name
end

function Gear.equip(data: Types.PlayerData, kind: string, id: string): (boolean, string)
	local name = lookup(kind, id)
	if name == nil then
		return false, "Unknown item"
	end
	if not ownedTable(data, kind)[id] then
		return false, "You don't own " .. name
	end
	if kind == "Weapon" then
		data.EquippedWeapon = id
	else
		data.EquippedArmor = id
	end
	return true, "Equipped " .. name
end

return Gear
