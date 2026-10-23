--!strict
-- Assigns base plots, handles planting / hatching / slot unlocks and drives the in-world visuals.
-- Growth is computed from saved unix timestamps, so eggs keep growing while the owner is offline.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Logic.Pets)
local Plot = require(ReplicatedStorage.Shared.Logic.Plot)
local Types = require(ReplicatedStorage.Shared.Logic.Types)
local Actions = require(script.Parent.Actions)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)
local Net = require(script.Parent.Net)
local PetService = require(script.Parent.PetService)

local PlotService = {}

local UPDATE_INTERVAL = 0.5
local LOCKED_COLOR = Color3.fromRGB(60, 60, 60)
local OPEN_COLOR = Color3.fromRGB(80, 60, 40)

type PadVisual = {
	Pad: BasePart,
	Prompt: ProximityPrompt,
	Label: TextLabel,
	Bar: Frame,
	Fill: Frame,
	Egg: BasePart?,
	EggRarity: string?,
}

local plotOf: { [Player]: MapService.PlotModel } = {}
local ownerOf: { [number]: Player } = {}
local pads: { [number]: { PadVisual } } = {}
local rng = Random.new()

local function formatTime(seconds: number): string
	if seconds >= 60 then
		return string.format("%dm %02ds", seconds // 60, seconds % 60)
	end
	return `{seconds}s`
end

local function makePadVisual(pad: BasePart): PadVisual
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Plant Egg"
	prompt.ObjectText = "Plot Slot"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	local gui = Instance.new("BillboardGui")
	gui.Name = "SlotGui"
	gui.Size = UDim2.fromOffset(130, 40)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.MaxDistance = 70
	gui.Parent = pad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0.6, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = ""
	label.Parent = gui

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0.3, 0)
	bar.Position = UDim2.fromScale(0, 0.68)
	bar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = gui

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = bar

	return {
		Pad = pad,
		Prompt = prompt,
		Label = label,
		Bar = bar,
		Fill = fill,
		Egg = nil,
		EggRarity = nil,
	}
end

local function setEgg(visual: PadVisual, rarity: string?)
	if visual.EggRarity == rarity then
		return
	end
	if visual.Egg then
		visual.Egg:Destroy()
		visual.Egg = nil
	end
	visual.EggRarity = rarity
	if not rarity then
		return
	end
	local egg = Instance.new("Part")
	egg.Name = "Egg"
	egg.Anchored = true
	egg.CanCollide = false
	egg.CanQuery = false
	egg.Size = Vector3.new(2, 2.6, 2)
	egg.Color = Config.Eggs[rarity].Color
	egg.CFrame = visual.Pad.CFrame * CFrame.new(0, 1.6, 0)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	egg.Parent = visual.Pad
	visual.Egg = egg
end

local function updatePad(visual: PadVisual, slotIndex: number, data: Types.PlayerData?, now: number)
	local prompt, label = visual.Prompt, visual.Label
	-- Prompt visibility is handled per player on the client (only the owner sees their prompts).
	if not data then
		visual.Pad.Color = OPEN_COLOR
		setEgg(visual, nil)
		prompt.ActionText = "Free Plot"
		label.Text = ""
		visual.Bar.Visible = false
		return
	end

	if slotIndex > data.UnlockedSlots then
		visual.Pad.Color = LOCKED_COLOR
		setEgg(visual, nil)
		visual.Bar.Visible = false
		if slotIndex == data.UnlockedSlots + 1 then
			local price = Plot.nextSlotPrice(data) or 0
			prompt.ActionText = `Unlock ({price} coins)`
			label.Text = `Locked - {price} coins`
		else
			prompt.ActionText = "Locked"
			label.Text = "Locked"
		end
		return
	end

	visual.Pad.Color = OPEN_COLOR
	local slot = data.Plot[tostring(slotIndex)]
	if not slot then
		setEgg(visual, nil)
		visual.Bar.Visible = false
		prompt.ActionText = "Plant Egg"
		label.Text = "Empty"
		return
	end

	setEgg(visual, slot.Rarity)
	local progress = Plot.progress(slot, now)
	local egg = visual.Egg
	if egg then
		local mesh = egg:FindFirstChildOfClass("SpecialMesh")
		if mesh then
			mesh.Scale = Vector3.one * (0.5 + 0.5 * progress)
		end
		egg.Material = if progress >= 1 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
	visual.Bar.Visible = true
	visual.Fill.Size = UDim2.fromScale(progress, 1)
	if Plot.isReady(slot, now) then
		prompt.ActionText = "Hatch!"
		label.Text = `{slot.Rarity} egg - Ready!`
		visual.Fill.BackgroundColor3 = Color3.fromRGB(255, 210, 60)
	else
		prompt.ActionText = "Growing..."
		label.Text = `{slot.Rarity} egg - {formatTime(Plot.secondsLeft(slot, now))}`
		visual.Fill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
	end
end

local function updatePlot(plotIndex: number)
	local owner = ownerOf[plotIndex]
	local data = owner and DataService.get(owner)
	local now = os.time()
	for slotIndex, visual in pads[plotIndex] do
		updatePad(visual, slotIndex, data, now)
	end
end

local function plant(_player: Player, data: Types.PlayerData, slotIndex: any, rarity: any): (boolean, string)
	if type(slotIndex) ~= "number" or type(rarity) ~= "string" then
		return false, "Invalid request"
	end
	return Plot.plant(data, slotIndex, rarity, os.time())
end

local function hatch(player: Player, data: Types.PlayerData, slotIndex: any): (boolean, string)
	if type(slotIndex) ~= "number" then
		return false, "Invalid request"
	end
	local ok, message, uid, petId = Plot.hatch(data, slotIndex, os.time(), function()
		return rng:NextNumber()
	end)
	if ok and uid and petId then
		if #data.EquippedPets < Config.Evolution.MaxEquipped then
			Pets.equip(data, uid)
			task.defer(PetService.refresh, player)
		end
		local plot = plotOf[player]
		local pad = plot and plot.Pads[slotIndex]
		if pad then
			Net.Effect:Fire(player, "Hatch", pad.Position + Vector3.new(0, 3, 0), petId)
		end
	end
	return ok, message
end

local function buySlot(_player: Player, data: Types.PlayerData): (boolean, string)
	return Plot.buySlot(data)
end

local function onPadTriggered(player: Player, plotIndex: number, slotIndex: number)
	if ownerOf[plotIndex] ~= player then
		DataService.notify(player, "This is not your plot", "error")
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end

	local ok, message
	if slotIndex > data.UnlockedSlots then
		if slotIndex ~= data.UnlockedSlots + 1 then
			ok, message = false, "Unlock the earlier slots first"
		else
			ok, message = buySlot(player, data)
		end
	else
		local slot = data.Plot[tostring(slotIndex)]
		if slot then
			ok, message = hatch(player, data, slotIndex)
		else
			local rarity = Plot.bestEgg(data)
			if rarity then
				ok, message = plant(player, data, slotIndex, rarity)
			else
				ok, message = false, "You have no eggs. Defeat monsters to find some!"
			end
		end
	end

	DataService.notify(player, message, if ok then "success" else "error")
	if ok then
		DataService.changed(player)
		updatePlot(plotIndex)
	end
end

local function assign(player: Player)
	if plotOf[player] then
		return
	end
	for _, plot in MapService.Plots do
		if not ownerOf[plot.Index] then
			ownerOf[plot.Index] = player
			plotOf[player] = plot
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			plot.Sign.Text = `{player.DisplayName}'s Plot`
			player:SetAttribute("PlotIndex", plot.Index)
			updatePlot(plot.Index)
			return
		end
	end
	DataService.notify(player, "All base plots are taken on this server", "error")
end

local function release(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	plotOf[player] = nil
	ownerOf[plot.Index] = nil
	plot.Model:SetAttribute("OwnerUserId", 0)
	plot.Sign.Text = "Free Plot"
	updatePlot(plot.Index)
end

function PlotService.teleportHome(player: Player): (boolean, string)
	local plot = plotOf[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not plot or not root or not root:IsA("BasePart") then
		return false, "You don't have a plot"
	end
	root.CFrame = CFrame.new(plot.Base.Position + Vector3.new(0, 4, -MapService.PlotSize / 2 + 6))
	return true, "Welcome home"
end

function PlotService.init()
	for _, plot in MapService.Plots do
		local visuals = {}
		for slotIndex, pad in plot.Pads do
			local visual = makePadVisual(pad)
			visual.Prompt.Triggered:Connect(function(player)
				onPadTriggered(player, plot.Index, slotIndex)
			end)
			visuals[slotIndex] = visual
		end
		pads[plot.Index] = visuals
		updatePlot(plot.Index)
	end

	DataService.onLoaded(assign)
	Players.PlayerRemoving:Connect(release)

	Actions.bind("PlantEgg", function(player, data, slotIndex, rarity)
		local ok, message = plant(player, data, slotIndex, rarity)
		local plot = plotOf[player]
		if ok and plot then
			task.defer(updatePlot, plot.Index)
		end
		return ok, message
	end)
	Actions.bind("HatchEgg", function(player, data, slotIndex)
		local ok, message = hatch(player, data, slotIndex)
		local plot = plotOf[player]
		if ok and plot then
			task.defer(updatePlot, plot.Index)
		end
		return ok, message
	end)
	Actions.bind("BuySlot", function(player, data)
		local ok, message = buySlot(player, data)
		local plot = plotOf[player]
		if ok and plot then
			task.defer(updatePlot, plot.Index)
		end
		return ok, message
	end)
	Actions.bind("TeleportHome", function(player)
		local ok, message = PlotService.teleportHome(player)
		return ok, if ok then nil else message
	end)

	task.spawn(function()
		while true do
			task.wait(UPDATE_INTERVAL)
			for index in ownerOf do
				updatePlot(index)
			end
		end
	end)
end

return PlotService
