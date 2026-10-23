--!strict
-- Equipped pets follow their owner using AlignPosition/AlignOrientation, owned by the player's
-- client for smooth movement.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Logic.Pets)
local Types = require(ReplicatedStorage.Shared.Logic.Types)
local Actions = require(script.Parent.Actions)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)

local PetService = {}

-- Offsets in the owner's HumanoidRootPart space (+Z is behind the player).
local FOLLOW_OFFSETS = {
	Vector3.new(-3.5, 1, 3),
	Vector3.new(3.5, 1, 3),
	Vector3.new(0, 2, 5),
}
local GOLD = Color3.fromRGB(255, 205, 50)

local spawned: { [Player]: { Instance } } = {}

local function clear(player: Player)
	local instances = spawned[player]
	if instances then
		for _, instance in instances do
			instance:Destroy()
		end
	end
	spawned[player] = nil
end

function PetService.displayName(pet: Types.PetData): string
	local cfg = Config.Pets[pet.Id]
	local stageName = Config.Evolution.StageNames[pet.Stage] or ""
	local name = if cfg then cfg.Name else pet.Id
	return if pet.Stage > 1 then `{stageName} {name}` else name
end

local function buildPet(pet: Types.PetData): Part
	local cfg = Config.Pets[pet.Id]
	local size = cfg.Size * (1 + 0.2 * (pet.Stage - 1))

	local body = Instance.new("Part")
	body.Name = "Pet"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.one * size
	body.CFrame = CFrame.new()
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	if pet.Stage == 1 then
		body.Color = cfg.Color
	elseif pet.Stage == 2 then
		body.Color = cfg.Color:Lerp(GOLD, 0.6)
		body.Material = Enum.Material.Foil
	else
		body.Color = cfg.Color
		body.Material = Enum.Material.Neon
		local sparkles = Instance.new("Sparkles")
		sparkles.Parent = body
	end

	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * size * 0.22
		eye.Color = Color3.new(0, 0, 0)
		eye.CanCollide = false
		eye.CanQuery = false
		eye.CanTouch = false
		eye.Massless = true
		local weld = Instance.new("Weld")
		weld.Part0 = body
		weld.Part1 = eye
		weld.C0 = CFrame.new(side * size * 0.2, size * 0.12, -size * 0.42)
		weld.Parent = eye
		eye.Parent = body
	end

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 26)
	gui.StudsOffset = Vector3.new(0, size / 2 + 0.8, 0)
	gui.MaxDistance = 60
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = if pet.Stage > 1 then GOLD else Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = PetService.displayName(pet)
	label.Parent = gui

	return body
end

function PetService.refresh(player: Player)
	clear(player)
	local data = DataService.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not data or not root or not root:IsA("BasePart") then
		return
	end

	local instances: { Instance } = {}
	for index, uid in data.EquippedPets do
		local pet = data.Pets[uid]
		if pet and Config.Pets[pet.Id] and FOLLOW_OFFSETS[index] then
			local offset = FOLLOW_OFFSETS[index]
			local body = buildPet(pet)
			body.CFrame = root.CFrame * CFrame.new(offset)
			body.Name = `{player.Name}_Pet{index}`

			local target = Instance.new("Attachment")
			target.Name = "PetTarget" .. index
			target.Position = offset
			target.Parent = root

			local attachment = Instance.new("Attachment")
			attachment.Parent = body

			local align = Instance.new("AlignPosition")
			align.Attachment0 = attachment
			align.Attachment1 = target
			align.MaxForce = 1e5
			align.Responsiveness = 25
			align.Parent = body

			local orient = Instance.new("AlignOrientation")
			orient.Attachment0 = attachment
			orient.Attachment1 = target
			orient.MaxTorque = 1e5
			orient.Responsiveness = 20
			orient.Parent = body

			body.Parent = MapService.Folders.Pets
			-- Network ownership can only be set on unanchored parts that are in the workspace.
			pcall(function()
				body:SetNetworkOwner(player)
			end)
			table.insert(instances, body)
			table.insert(instances, target)
		end
	end
	spawned[player] = instances
end

local function validUid(uid: any): boolean
	return type(uid) == "string" and #uid < 20
end

function PetService.init()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			PetService.refresh(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(clear)
	DataService.onLoaded(function(player)
		PetService.refresh(player)
	end)

	Actions.bind("EquipPet", function(player, data, uid)
		if not validUid(uid) then
			return false, "Invalid pet"
		end
		local ok, message = Pets.equip(data, uid)
		if ok then
			task.defer(PetService.refresh, player)
		end
		return ok, message
	end)

	Actions.bind("UnequipPet", function(player, data, uid)
		if not validUid(uid) then
			return false, "Invalid pet"
		end
		local ok, message = Pets.unequip(data, uid)
		if ok then
			task.defer(PetService.refresh, player)
		end
		return ok, message
	end)

	Actions.bind("MergePet", function(player, data, uid)
		if not validUid(uid) then
			return false, "Invalid pet"
		end
		local ok, message = Pets.merge(data, uid)
		if ok then
			task.defer(PetService.refresh, player)
		end
		return ok, message
	end)

	Actions.bind("FeedPet", function(player, data, uid)
		if not validUid(uid) then
			return false, "Invalid pet"
		end
		local ok, message = Pets.feed(data, uid)
		if ok and Pets.isEquipped(data, uid) then
			task.defer(PetService.refresh, player)
		end
		return ok, message
	end)
end

return PetService
