--!strict
-- Player loadout (weapon tool, armor, max health), server-side hit checks and kill rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Gear = require(ReplicatedStorage.Shared.Logic.Gear)
local Leveling = require(ReplicatedStorage.Shared.Logic.Leveling)
local Pets = require(ReplicatedStorage.Shared.Logic.Pets)
local Rewards = require(ReplicatedStorage.Shared.Logic.Rewards)
local Types = require(ReplicatedStorage.Shared.Logic.Types)
local WeaponsConfig = require(ReplicatedStorage.Shared.Config.Weapons)
local ZonesConfig = require(ReplicatedStorage.Shared.Config.Zones)
local DataService = require(script.Parent.DataService)
local MonsterService = require(script.Parent.MonsterService)
local Net = require(script.Parent.Net)

local CombatService = {}

local WEAPON_ATTRIBUTE = "GameWeapon"
-- Attacks only hit monsters roughly in front of the player (dot product with the look vector).
local FRONT_DOT = 0.2

local lastAttack: { [Player]: number } = {}
local rng = Random.new()

local function rollRng(): number
	return rng:NextNumber()
end

local function getCharacterParts(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return character, nil, nil
	end
	return character, humanoid, root
end

-- Called from the client's Attack remote; the client plays the swing animation itself.
local function attack(player: Player)
	local data = DataService.get(player)
	local _, humanoid, root = getCharacterParts(player)
	if not data or not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local weapon = Gear.getWeapon(data.EquippedWeapon) or Config.Weapons[1]
	local now = os.clock()
	-- Small tolerance so network jitter doesn't eat legitimate clicks.
	if lastAttack[player] and now - lastAttack[player] < weapon.Cooldown * 0.9 then
		return
	end
	lastAttack[player] = now

	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local origin = Vector3.new(root.Position.X, 0, root.Position.Z)
	local best: MonsterService.Monster? = nil
	local bestDistance = math.huge
	for _, monster in MonsterService.monsters do
		local offset = monster.Position - origin
		local distance = offset.Magnitude - monster.Config.Size.X / 2
		if distance <= weapon.Range and distance < bestDistance then
			local inFront = offset.Magnitude < 2 or offset.Unit:Dot(look) >= FRONT_DOT
			if inFront then
				best, bestDistance = monster, distance
			end
		end
	end
	if not best then
		return
	end
	if data.Level < best.Zone.LevelRequired then
		DataService.notify(player, `You need level {best.Zone.LevelRequired} to fight here`, "error")
		return
	end

	local raw = (weapon.Damage + Leveling.baseDamage(data.Level)) * Pets.getMultipliers(data).Damage
	local damage = math.max(1, math.floor(raw + 0.5))
	local popupAt = MonsterService.worldPosition(best) + Vector3.new(0, best.Config.Size.Y / 2 + 1, 0)
	MonsterService.damage(best, damage, player)
	Net.Effect:Fire(player, "Damage", popupAt, damage)
end

local function buildTool(weapon: WeaponsConfig.Weapon): Tool
	local tool = Instance.new("Tool")
	tool.Name = weapon.Name
	tool.ToolTip = `{weapon.Damage} damage`
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute(WEAPON_ATTRIBUTE, weapon.Id)
	-- Blade runs along the handle's Z axis with the grip near the -Z end.
	tool.Grip =
		CFrame.fromMatrix(Vector3.new(0, 0, -(weapon.Length / 2 - 0.5)), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1))

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.4, weapon.Length)
	handle.Color = weapon.Color
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = tool

	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(0.4, 1.4, 0.3)
	guard.Color = Color3.fromRGB(90, 70, 40)
	guard.CanCollide = false
	guard.Massless = true
	guard.Parent = tool
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = guard
	weld.C0 = CFrame.new(0, 0, -weapon.Length / 2 + 1)
	weld.Parent = handle
	return tool
end

local function removeWeapons(player: Player)
	local containers: { Instance? } = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute(WEAPON_ATTRIBUTE) then
					child:Destroy()
				end
			end
		end
	end
end

local function applyArmor(character: Model, data: Types.PlayerData)
	local old = character:FindFirstChild("ArmorPlate")
	if old then
		old:Destroy()
	end
	local armor = Gear.getArmor(data.EquippedArmor)
	if not armor then
		return
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local plate = Instance.new("Part")
	plate.Name = "ArmorPlate"
	plate.Size = torso.Size + Vector3.new(0.3, 0.2, 0.3)
	plate.Color = armor.Color
	plate.Material = Enum.Material.Metal
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	plate.Massless = true
	plate.CFrame = torso.CFrame
	local weld = Instance.new("Weld")
	weld.Part0 = torso
	weld.Part1 = plate
	weld.Parent = plate
	plate.Parent = character
end

-- Rebuilds the weapon tool, armor and max health from saved data.
function CombatService.refreshLoadout(player: Player, healFull: boolean?)
	local data = DataService.get(player)
	local character, humanoid = getCharacterParts(player)
	if not data or not character or not humanoid then
		return
	end

	local maxHealth = Leveling.maxHealth(data)
	local wasFull = humanoid.Health >= humanoid.MaxHealth
	humanoid.MaxHealth = maxHealth
	if healFull or wasFull then
		humanoid.Health = maxHealth
	else
		humanoid.Health = math.min(humanoid.Health, maxHealth)
	end

	applyArmor(character, data)

	local weapon = Gear.getWeapon(data.EquippedWeapon) or Config.Weapons[1]
	local current = character:FindFirstChildOfClass("Tool")
	if current and current:GetAttribute(WEAPON_ATTRIBUTE) == weapon.Id then
		return
	end
	removeWeapons(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local tool = buildTool(weapon)
	tool.Parent = backpack
	humanoid:EquipTool(tool)
end

local function onKilled(monster: MonsterService.Monster, killer: Player?)
	if not killer then
		return
	end
	local data = DataService.get(killer)
	if not data then
		return
	end
	local result = Rewards.applyKill(data, monster.Name, monster.Zone, rollRng)
	local position = MonsterService.worldPosition(monster)
	Net.Effect:Fire(killer, "Reward", position, `+{result.Coins} coins  +{result.XP} XP`)
	if result.Egg then
		if result.EggLost then
			DataService.notify(killer, "Your egg storage is full! Plant some eggs.", "error")
		else
			Net.Effect:Fire(killer, "Egg", position, result.Egg)
			DataService.notify(killer, `You found a {result.Egg} egg!`, "reward")
		end
	end
	if result.LevelsGained > 0 then
		DataService.notify(killer, `Level up! You are now level {data.Level}`, "success")
		CombatService.refreshLoadout(killer, true)
	end
	DataService.changed(killer)
end

local function onAttackPlayer(monster: MonsterService.Monster, player: Player)
	local data = DataService.get(player)
	local _, humanoid = getCharacterParts(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local reduction = 0
	local armor = data and Gear.getArmor(data.EquippedArmor)
	if armor then
		reduction = armor.DamageReduction
	end
	humanoid:TakeDamage(monster.Config.Damage * (1 - reduction))
end

local function canTarget(player: Player, zone: ZonesConfig.Zone): boolean
	local data = DataService.get(player)
	return data ~= nil and data.Level >= zone.LevelRequired
end

local function onCharacterAdded(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", 10)
	character:WaitForChild("Humanoid", 10)
	-- Torso parts may still be streaming in for R15 rigs; armor needs them.
	if not character:FindFirstChild("UpperTorso") and not character:FindFirstChild("Torso") then
		character:WaitForChild("UpperTorso", 3)
	end
	-- Equipping before the hand exists leaves the sword unwelded, so it falls out of the world.
	if not character:FindFirstChild("RightHand") and not character:FindFirstChild("Right Arm") then
		character:WaitForChild("RightHand", 3)
	end
	if player.Character == character then
		CombatService.refreshLoadout(player, true)
	end
end

function CombatService.init()
	MonsterService.onKilled = onKilled
	MonsterService.onAttackPlayer = onAttackPlayer
	MonsterService.canTarget = canTarget
	Net.Attack:Connect(attack)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
	end)

	-- Characters can spawn before data finishes loading.
	DataService.onLoaded(function(player)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end)
end

return CombatService
