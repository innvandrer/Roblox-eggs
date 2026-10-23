--!strict
-- Client-only visual effects requested by the server: damage numbers, reward text, egg drops, hatches.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(script.Parent.Net)
local Notifications = require(script.Parent.Notifications)
local Ui = require(script.Parent.Ui)

local Effects = {}

local function anchorAt(position: Vector3): Part
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position
	anchor.Parent = workspace
	return anchor
end

local function floatingText(position: Vector3, text: string, color: Color3, duration: number)
	local anchor = anchorAt(position)
	local gui = Ui.new("BillboardGui", {
		Size = UDim2.fromOffset(200, 40),
		AlwaysOnTop = true,
		Parent = anchor,
	})
	local label = Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Ui.Font,
		TextScaled = true,
		TextColor3 = color,
		TextStrokeTransparency = 0.2,
		Text = text,
		Parent = gui,
	})
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { Position = position + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(duration, function()
		anchor:Destroy()
	end)
end

local function eggDrop(position: Vector3, rarity: string)
	local egg = Config.Eggs[rarity]
	if not egg then
		return
	end
	local part = anchorAt(position + Vector3.new(0, 1, 0))
	part.Transparency = 0
	part.Size = Vector3.new(1.4, 1.8, 1.4)
	part.Color = egg.Color
	part.Material = Enum.Material.Neon
	Ui.new("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = part })

	TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = position + Vector3.new(0, 4, 0),
	}):Play()
	task.delay(0.5, function()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = root.Position,
				Size = Vector3.one * 0.3,
			}):Play()
		end
		task.wait(0.4)
		part:Destroy()
	end)
end

local function hatch(position: Vector3, petId: string)
	local pet = Config.Pets[petId]
	if not pet then
		return
	end
	local burst = anchorAt(position)
	burst.Transparency = 0.2
	burst.Shape = Enum.PartType.Ball
	burst.Material = Enum.Material.Neon
	burst.Color = pet.Color
	burst.Size = Vector3.one
	local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(burst, info, { Size = Vector3.one * 8, Transparency = 1 }):Play()
	task.delay(0.6, function()
		burst:Destroy()
	end)
	Notifications.banner(`You hatched a {pet.Rarity} {pet.Name}!`)
end

function Effects.init()
	Net.Effect:Connect(function(kind: string, position: Vector3, value: any)
		if typeof(position) ~= "Vector3" then
			return
		end
		if kind == "Damage" then
			floatingText(position, tostring(value), Color3.fromRGB(255, 90, 90), 0.7)
		elseif kind == "Reward" then
			floatingText(position + Vector3.new(0, 2, 0), tostring(value), Ui.Colors.Gold, 1.4)
		elseif kind == "Egg" then
			eggDrop(position, tostring(value))
		elseif kind == "Hatch" then
			hatch(position, tostring(value))
		end
	end)
end

return Effects
