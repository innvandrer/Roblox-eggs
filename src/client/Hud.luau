--!strict
-- Always-visible main screen: coins, level, XP bar, egg count and menu buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Menus = require(script.Parent.Menus)
local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local Hud = {}

function Hud.create(screen: ScreenGui)
	local top = Ui.new("Frame", {
		Name = "Stats",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(460, 78),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.15,
		Parent = screen,
	}, { Ui.corner(12) })

	local coins = Ui.label({
		Text = "Coins: 0",
		TextColor3 = Ui.Colors.Gold,
		Size = UDim2.new(0.5, -12, 0, 28),
		Position = UDim2.fromOffset(12, 6),
		MaxTextSize = 26,
		Parent = top,
	})
	local level = Ui.label({
		Text = "Level 1",
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0.5, -12, 0, 28),
		Position = UDim2.new(0.5, 0, 0, 6),
		MaxTextSize = 26,
		Parent = top,
	})
	local _, xpFill = Ui.progressBar(top, {
		Size = UDim2.new(1, -24, 0, 14),
		Position = UDim2.fromOffset(12, 38),
		Color = Ui.Colors.Blue,
	})
	local detail = Ui.label({
		Text = "",
		TextColor3 = Ui.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(12, 55),
		MaxTextSize = 15,
		Parent = top,
	})

	local side = Ui.new("Frame", {
		Name = "MenuButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(130, 230),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local buttons: { { any } } = {
		{ "Shop  [B]", "Shop", Ui.Colors.Green },
		{ "Pets  [P]", "Pets", Ui.Colors.Purple },
		{ "Plot  [G]", "Plot", Color3.fromRGB(150, 100, 60) },
	}
	for index, def in buttons do
		Ui.button({
			Text = def[1],
			BackgroundColor3 = def[3],
			Size = UDim2.new(1, 0, 0, 48),
			LayoutOrder = index,
			MaxTextSize = 22,
			Parent = side,
		}, function()
			Menus.toggle(def[2])
		end)
	end
	Ui.button({
		Text = "Home",
		BackgroundColor3 = Ui.Colors.Grey,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 10,
		MaxTextSize = 20,
		Parent = side,
	}, function()
		Net.send("TeleportHome")
	end)

	local hotkeys = {
		[Enum.KeyCode.B] = "Shop",
		[Enum.KeyCode.P] = "Pets",
		[Enum.KeyCode.G] = "Plot",
	}
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local menu = hotkeys[input.KeyCode]
		if menu then
			Menus.toggle(menu)
		elseif input.KeyCode == Enum.KeyCode.Escape then
			Menus.close()
		end
	end)

	State.onChanged(function(snapshot)
		local data = snapshot.Data
		coins.Text = "Coins: " .. Ui.formatNumber(data.Coins)
		level.Text = `Level {data.Level}`
		local atMax = data.Level >= Config.Leveling.MaxLevel
		xpFill.Size = UDim2.fromScale(if atMax then 1 else math.clamp(data.XP / snapshot.XpToNext, 0, 1), 1)
		local eggs = 0
		for _, count in data.Eggs do
			eggs += count
		end
		local xpText = if atMax then "MAX" else `{data.XP}/{snapshot.XpToNext} XP`
		detail.Text = string.format(
			"%s   |   Eggs: %d   |   Damage x%.2f   Coins x%.2f",
			xpText,
			eggs,
			snapshot.Multipliers.Damage,
			snapshot.Multipliers.Coins
		)
	end)
end

return Hud
