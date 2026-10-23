--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Plot = require(ReplicatedStorage.Shared.Logic.Plot)
local Types = require(ReplicatedStorage.Shared.Logic.Types)
local Menus = require(script.Parent.Menus)
local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local PlotMenu = {}

type Timer = {
	Slot: Types.SlotData,
	Fill: Frame,
	Label: TextLabel,
	WasReady: boolean,
}

local function sortedEggs(data: Types.PlayerData): { string }
	local rarities = {}
	for rarity, count in data.Eggs do
		if count > 0 and Config.Eggs[rarity] then
			table.insert(rarities, rarity)
		end
	end
	table.sort(rarities, function(a, b)
		return Config.Eggs[a].Order > Config.Eggs[b].Order
	end)
	return rarities
end

function PlotMenu.create(screen: ScreenGui)
	local _, body = Menus.createPanel(screen, "Plot", "My Plot")

	local eggsLabel = Ui.label({
		Text = "",
		Size = UDim2.new(1, -170, 0, 22),
		Parent = body,
	})
	Ui.label({
		Text = "Eggs keep growing while you're offline. You can also walk up to a slot and press E.",
		TextColor3 = Ui.Colors.Muted,
		Size = UDim2.new(1, -170, 0, 18),
		Position = UDim2.fromOffset(0, 24),
		MaxTextSize = 15,
		Parent = body,
	})
	Ui.button({
		Text = "Go to my plot",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(160, 38),
		Parent = body,
	}, function()
		Net.send("TeleportHome")
		Menus.close()
	end)
	local list = Ui.list(body, {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
	})

	local timers: { Timer } = {}
	local refresh: (State.Snapshot) -> ()

	local function updateTimers()
		local now = State.now()
		for _, timer in timers do
			local progress = Plot.progress(timer.Slot, now)
			timer.Fill.Size = UDim2.fromScale(progress, 1)
			local ready = Plot.isReady(timer.Slot, now)
			timer.Label.Text = if ready then "Ready!" else Ui.formatTime(Plot.secondsLeft(timer.Slot, now))
			if ready and not timer.WasReady and State.current then
				-- Rebuild so the Hatch button becomes active.
				refresh(State.current)
				return
			end
		end
	end

	function refresh(snapshot: State.Snapshot)
		local data = snapshot.Data
		local now = State.now()
		local eggs = sortedEggs(data)
		local parts = {}
		for _, rarity in eggs do
			table.insert(parts, `{rarity} x{data.Eggs[rarity]}`)
		end
		eggsLabel.Text = if #parts > 0 then "Eggs: " .. table.concat(parts, ", ") else "Eggs: none yet"

		Ui.clear(list)
		table.clear(timers)
		for slotIndex = 1, Config.Plots.MaxSlots do
			local row = Ui.row(list, 52, slotIndex)
			local title = Ui.label({
				Text = `Slot {slotIndex}`,
				Size = UDim2.new(0, 170, 0, 24),
				Position = UDim2.fromOffset(12, 14),
				Parent = row,
			})

			if slotIndex > data.UnlockedSlots then
				title.TextColor3 = Ui.Colors.Muted
				title.Text = `Slot {slotIndex} - Locked`
				if slotIndex == data.UnlockedSlots + 1 and snapshot.NextSlotPrice then
					local price = snapshot.NextSlotPrice
					Ui.button({
						Text = `Unlock {Ui.formatNumber(price)}`,
						BackgroundColor3 = if data.Coins >= price then Ui.Colors.Green else Ui.Colors.Grey,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.fromOffset(140, 36),
						Parent = row,
					}, function()
						Net.send("BuySlot")
					end)
				end
			else
				local slot = data.Plot[tostring(slotIndex)]
				if slot then
					title.Text = `Slot {slotIndex} - {slot.Rarity} egg`
					title.TextColor3 = Ui.rarityColor(slot.Rarity)
					local _, fill = Ui.progressBar(row, {
						Size = UDim2.new(1, -420, 0, 16),
						Position = UDim2.fromOffset(190, 18),
					})
					local timeLabel = Ui.label({
						Text = "",
						Size = UDim2.fromOffset(80, 20),
						Position = UDim2.new(1, -220, 0, 16),
						MaxTextSize = 16,
						Parent = row,
					})
					local ready = Plot.isReady(slot, now)
					table.insert(timers, { Slot = slot, Fill = fill, Label = timeLabel, WasReady = ready })
					Ui.button({
						Text = "Hatch",
						BackgroundColor3 = if ready then Ui.Colors.Gold else Ui.Colors.Grey,
						TextColor3 = if ready then Color3.new(0.1, 0.1, 0.1) else Ui.Colors.Text,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.fromOffset(120, 36),
						Parent = row,
					}, function()
						Net.send("HatchEgg", slotIndex)
					end)
				else
					title.Text = `Slot {slotIndex} - Empty`
					local buttons = Ui.new("Frame", {
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.new(1, -200, 0, 36),
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
					if #eggs == 0 then
						Ui.label({
							Text = "No eggs to plant",
							TextColor3 = Ui.Colors.Muted,
							TextXAlignment = Enum.TextXAlignment.Right,
							Size = UDim2.fromOffset(160, 20),
							MaxTextSize = 16,
							Parent = buttons,
						})
					end
					for order, rarity in eggs do
						local color = Ui.rarityColor(rarity)
						Ui.button({
							Text = `Plant {rarity}`,
							BackgroundColor3 = color,
							TextColor3 = Color3.new(0.1, 0.1, 0.1),
							Size = UDim2.fromOffset(120, 34),
							LayoutOrder = order,
							MaxTextSize = 16,
							Parent = buttons,
						}, function()
							Net.send("PlantEgg", slotIndex, rarity)
						end)
					end
				end
			end
		end
		updateTimers()
	end

	State.onChanged(refresh)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.25 and Menus.isOpen("Plot") then
			elapsed = 0
			updateTimers()
		end
	end)
end

return PlotMenu
