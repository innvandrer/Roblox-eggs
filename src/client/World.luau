--!strict
-- Per-player world tweaks: solid level walls, owner-only plot prompts, and the shop prompt.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Menus = require(script.Parent.Menus)
local State = require(script.Parent.State)

local World = {}

local player = Players.LocalPlayer
local currentLevel = 0

local function updateWall(wall: Instance)
	if not wall:IsA("BasePart") then
		return
	end
	local required = wall:GetAttribute("LevelRequired")
	local locked = type(required) == "number" and currentLevel < required
	wall.CanCollide = locked
	wall.Transparency = if locked then 0.4 else 0.92
end

local function updateWalls()
	for _, wall in CollectionService:GetTagged("LevelWall") do
		updateWall(wall)
	end
end

local function updatePlotPrompts()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in plots:GetChildren() do
		local mine = plot:GetAttribute("OwnerUserId") == player.UserId
		for _, descendant in plot:GetDescendants() do
			if descendant:IsA("ProximityPrompt") and descendant.Enabled ~= mine then
				descendant.Enabled = mine
			end
		end
	end
end

function World.init()
	CollectionService:GetInstanceAddedSignal("LevelWall"):Connect(updateWall)
	State.onChanged(function(snapshot)
		if snapshot.Data.Level ~= currentLevel then
			currentLevel = snapshot.Data.Level
			updateWalls()
		end
	end)
	updateWalls()

	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredBy)
		if triggeredBy ~= player then
			return
		end
		local menu = prompt:GetAttribute("OpensMenu")
		if type(menu) == "string" then
			Menus.open(menu)
		end
	end)

	task.spawn(function()
		while true do
			updatePlotPrompts()
			task.wait(0.5)
		end
	end)
end

return World
