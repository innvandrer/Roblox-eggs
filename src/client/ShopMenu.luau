--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Menus = require(script.Parent.Menus)
local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local ShopMenu = {}

type Item = {
	Kind: string,
	Id: string,
	Name: string,
	Price: number,
	LevelRequired: number,
	Color: Color3,
	Stats: string,
}

local function items(): { Item }
	local result = {}
	for _, weapon in Config.Weapons do
		table.insert(result, {
			Kind = "Weapon",
			Id = weapon.Id,
			Name = weapon.Name,
			Price = weapon.Price,
			LevelRequired = weapon.LevelRequired,
			Color = weapon.Color,
			Stats = `Damage {weapon.Damage}  |  Cooldown {weapon.Cooldown}s  |  Range {weapon.Range}`,
		})
	end
	for _, armor in Config.Armor do
		table.insert(result, {
			Kind = "Armor",
			Id = armor.Id,
			Name = armor.Name,
			Price = armor.Price,
			LevelRequired = armor.LevelRequired,
			Color = armor.Color,
			Stats = `+{armor.HealthBonus} max health  |  {math.floor(armor.DamageReduction * 100)}% damage reduction`,
		})
	end
	return result
end

function ShopMenu.create(screen: ScreenGui)
	local _, body = Menus.createPanel(screen, "Shop", "Gear Shop")
	local list = Ui.list(body)
	local allItems = items()

	local function refresh(snapshot: State.Snapshot)
		local data = snapshot.Data
		Ui.clear(list)
		for order, item in allItems do
			local row = Ui.row(list, 58, order)
			Ui.new("Frame", {
				BackgroundColor3 = item.Color,
				Size = UDim2.fromOffset(38, 38),
				Position = UDim2.fromOffset(10, 10),
				Parent = row,
			}, { Ui.corner(6) })
			Ui.label({
				Text = `{item.Name}  ({item.Kind})`,
				Size = UDim2.new(1, -200, 0, 24),
				Position = UDim2.fromOffset(58, 6),
				Parent = row,
			})
			Ui.label({
				Text = item.Stats,
				TextColor3 = Ui.Colors.Muted,
				Size = UDim2.new(1, -200, 0, 18),
				Position = UDim2.fromOffset(58, 32),
				MaxTextSize = 15,
				Parent = row,
			})

			local owned = if item.Kind == "Weapon" then data.OwnedWeapons[item.Id] else data.OwnedArmor[item.Id]
			local equipped = if item.Kind == "Weapon"
				then data.EquippedWeapon == item.Id
				else data.EquippedArmor == item.Id
			local text, color, action
			if equipped then
				text, color = "Equipped", Ui.Colors.Grey
				if item.Kind == "Armor" then
					text, action = "Unequip", function()
						Net.send("UnequipArmor")
					end
				end
			elseif owned then
				text, color, action =
					"Equip", Ui.Colors.Blue, function()
						Net.send("EquipItem", item.Kind, item.Id)
					end
			elseif data.Level < item.LevelRequired then
				text, color = `Level {item.LevelRequired}`, Ui.Colors.Grey
			else
				local affordable = data.Coins >= item.Price
				text = `Buy {Ui.formatNumber(item.Price)}`
				color = if affordable then Ui.Colors.Green else Color3.fromRGB(120, 100, 60)
				action = function()
					Net.send("BuyItem", item.Kind, item.Id)
				end
			end
			Ui.button({
				Text = text,
				BackgroundColor3 = color,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(130, 38),
				AutoButtonColor = action ~= nil,
				Parent = row,
			}, function()
				if action then
					action()
				end
			end)
		end
	end

	State.onChanged(refresh)
end

return ShopMenu
