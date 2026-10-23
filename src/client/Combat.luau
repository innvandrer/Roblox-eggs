--!strict
-- Turns clicks / taps / gamepad R2 into sword swings: plays the swing locally for instant feedback
-- and tells the server, which does the cooldown, range and hit checks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Gear = require(ReplicatedStorage.Shared.Logic.Gear)
local Net = require(script.Parent.Net)
local State = require(script.Parent.State)

local Combat = {}

-- Roblox's default "toolslash" animations.
local SLASH_ANIMATION = {
	R15 = "rbxassetid://522635514",
	R6 = "rbxassetid://129967390",
}

local player = Players.LocalPlayer
local lastSwing = 0
local slashTrack: AnimationTrack? = nil
local trackOwner: Humanoid? = nil

local function getHumanoid(): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil
	end
	return humanoid, root
end

local function playAnimation(humanoid: Humanoid)
	if trackOwner ~= humanoid then
		slashTrack = nil
		trackOwner = humanoid
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local animation = Instance.new("Animation")
			animation.AnimationId = if humanoid.RigType == Enum.HumanoidRigType.R15
				then SLASH_ANIMATION.R15
				else SLASH_ANIMATION.R6
			local ok, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)
			if ok then
				track.Priority = Enum.AnimationPriority.Action
				slashTrack = track
			end
		end
	end
	local track = slashTrack
	if track then
		track:Play(0.05)
	end
end

-- A quick arc in front of the player, so a swing is visible even if the animation fails to load.
local function slashEffect(root: BasePart, range: number)
	local arc = Instance.new("Part")
	arc.Anchored = true
	arc.CanCollide = false
	arc.CanQuery = false
	arc.CanTouch = false
	arc.Material = Enum.Material.Neon
	arc.Color = Color3.new(1, 1, 1)
	arc.Transparency = 0.4
	arc.Size = Vector3.new(range * 1.2, 0.15, 0.6)
	arc.CFrame = root.CFrame * CFrame.new(0, 0, -range * 0.55) * CFrame.Angles(0, 0, math.rad(-20))
	arc.Parent = workspace
	TweenService:Create(arc, TweenInfo.new(0.15), { Transparency = 1 }):Play()
	task.delay(0.15, function()
		arc:Destroy()
	end)
end

local function swing()
	local humanoid, root = getHumanoid()
	if not humanoid or not root then
		return
	end
	local snapshot = State.current
	local weapon = (snapshot and Gear.getWeapon(snapshot.Data.EquippedWeapon)) or Config.Weapons[1]
	local now = os.clock()
	if now - lastSwing < weapon.Cooldown then
		return
	end
	lastSwing = now
	playAnimation(humanoid)
	slashEffect(root, weapon.Range)
	Net.Attack:Fire()
end

function Combat.init()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonR2
		then
			swing()
		end
	end)

	local function watchCharacter(character: Model)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child:GetAttribute("GameWeapon") then
				child.Activated:Connect(swing)
			end
		end)
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

return Combat
