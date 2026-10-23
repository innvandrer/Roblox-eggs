--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Logic.Pets)
local Types = require(ReplicatedStorage.Shared.Logic.Types)
local Menus = require(script.Parent.Menus)
local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local PetsMenu = {}

local GOLD = Color3.fromRGB(255, 205, 50)

local function displayName(pet: Types.PetData): string
	local cfg = Config.Pets[pet.Id]
	local name = if cfg then cfg.Name else pet.Id
	if pet.Stage > 1 then
		return `{Config.Evolution.StageNames[pet.Stage]} {name}`
	end
	return name
end

local function rarityOrder(pet: Types.PetData): number
	local cfg = Config.Pets[pet.Id]
	local egg = cfg and Config.Eggs[cfg.Rarity]
	return if egg then egg.Order else 0
end

local function countMatches(data: Types.PlayerData, pet: Types.PetData): number
	local n = 0
	for _, other in data.Pets do
		if other.Id == pet.Id and other.Stage == pet.Stage then
			n += 1
		end
	end
	return n
end

function PetsMenu.create(screen: ScreenGui)
	local _, body = Menus.createPanel(screen, "Pets", "Pets")

	local summary = Ui.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 22),
		Parent = body,
	})
	Ui.label({
		Text = `Evolve a pet by merging {Config.Evolution.MergeCount} of the same pet and stage, or by feeding it coins.`,
		TextColor3 = Ui.Colors.Muted,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 24),
		MaxTextSize = 15,
		Parent = body,
	})
	local list = Ui.list(body, {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
	})

	local function refresh(snapshot: State.Snapshot)
		local data = snapshot.Data
		local m = snapshot.Multipliers
		summary.Text = string.format(
			"Equipped %d/%d   |   Damage x%.2f   |   Coins x%.2f",
			#data.EquippedPets,
			Config.Evolution.MaxEquipped,
			m.Damage,
			m.Coins
		)

		local uids = {}
		for uid in data.Pets do
			table.insert(uids, uid)
		end
		table.sort(uids, function(a, b)
			local pa, pb = data.Pets[a], data.Pets[b]
			local ea, eb = Pets.isEquipped(data, a), Pets.isEquipped(data, b)
			if ea ~= eb then
				return ea
			end
			if rarityOrder(pa) ~= rarityOrder(pb) then
				return rarityOrder(pa) > rarityOrder(pb)
			end
			if pa.Stage ~= pb.Stage then
				return pa.Stage > pb.Stage
			end
			if pa.Id ~= pb.Id then
				return pa.Id < pb.Id
			end
			return (tonumber(a) or 0) < (tonumber(b) or 0)
		end)

		Ui.clear(list)
		if #uids == 0 then
			Ui.label({
				Text = "No pets yet. Plant eggs on your plot and hatch them!",
				TextColor3 = Ui.Colors.Muted,
				Size = UDim2.new(1, 0, 0, 30),
				Parent = list,
			})
			return
		end

		for order, uid in uids do
			local pet = data.Pets[uid]
			local cfg = Config.Pets[pet.Id]
			if cfg then
				local equipped = Pets.isEquipped(data, uid)
				local row = Ui.row(list, 64, order)
				if equipped then
					Ui.new("UIStroke", { Color = Ui.Colors.Green, Thickness = 2, Parent = row })
				end
				Ui.new("Frame", {
					BackgroundColor3 = if pet.Stage == 2 then cfg.Color:Lerp(GOLD, 0.6) else cfg.Color,
					Size = UDim2.fromOffset(44, 44),
					Position = UDim2.fromOffset(10, 10),
					Parent = row,
				}, { Ui.corner(22) })
				Ui.label({
					Text = displayName(pet),
					TextColor3 = Ui.rarityColor(cfg.Rarity),
					Size = UDim2.new(1, -380, 0, 24),
					Position = UDim2.fromOffset(64, 8),
					Parent = row,
				})
				Ui.label({
					Text = `{cfg.Rarity}  |  +{math.floor(Pets.boostOf(pet) * 100 + 0.5)}% {cfg.BoostType}`,
					TextColor3 = Ui.Colors.Muted,
					Size = UDim2.new(1, -380, 0, 18),
					Position = UDim2.fromOffset(64, 36),
					MaxTextSize = 15,
					Parent = row,
				})

				local buttons = Ui.new("Frame", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromOffset(300, 40),
					Parent = row,
				}, {
					Ui.new("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
				})

				Ui.button({
					Text = if equipped then "Unequip" else "Equip",
					BackgroundColor3 = if equipped then Ui.Colors.Grey else Ui.Colors.Green,
					Size = UDim2.fromOffset(84, 36),
					LayoutOrder = 1,
					Parent = buttons,
				}, function()
					Net.send(if equipped then "UnequipPet" else "EquipPet", uid)
				end)

				local cost = Pets.feedCost(pet)
				Ui.button({
					Text = if cost then `Feed {Ui.formatNumber(cost)}` else "Max stage",
					BackgroundColor3 = if cost and data.Coins >= cost then Ui.Colors.Gold else Ui.Colors.Grey,
					TextColor3 = if cost and data.Coins >= cost then Color3.new(0.1, 0.1, 0.1) else Ui.Colors.Text,
					Size = UDim2.fromOffset(110, 36),
					LayoutOrder = 2,
					Parent = buttons,
				}, function()
					if cost then
						Net.send("FeedPet", uid)
					end
				end)

				if pet.Stage < Config.Evolution.MaxStage then
					local have = countMatches(data, pet)
					local canMerge = have >= Config.Evolution.MergeCount
					Ui.button({
						Text = `Merge {math.min(have, Config.Evolution.MergeCount)}/{Config.Evolution.MergeCount}`,
						BackgroundColor3 = if canMerge then Ui.Colors.Purple else Ui.Colors.Grey,
						Size = UDim2.fromOffset(90, 36),
						LayoutOrder = 3,
						Parent = buttons,
					}, function()
						if canMerge then
							Net.send("MergePet", uid)
						end
					end)
				end
			end
		end
	end

	State.onChanged(refresh)
end

return PetsMenu
