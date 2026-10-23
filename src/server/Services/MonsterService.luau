--!strict
-- Spawns monsters in each zone and runs their AI: wander, chase players in range, attack.
-- Monsters are anchored part models moved with PivotTo; they never leave their zone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local MonstersConfig = require(ReplicatedStorage.Shared.Config.Monsters)
local Weighted = require(ReplicatedStorage.Shared.Logic.Weighted)
local ZonesConfig = require(ReplicatedStorage.Shared.Config.Zones)
local MapService = require(script.Parent.MapService)

export type Monster = {
	Id: number,
	Name: string,
	Config: MonstersConfig.Monster,
	Zone: ZonesConfig.Zone,
	Model: Model,
	Body: BasePart,
	HealthBar: Frame,
	Health: number,
	Position: Vector3,
	Facing: Vector3,
	WanderTarget: Vector3?,
	NextWanderAt: number,
	LastAttackAt: number,
	Dead: boolean,
	Phase: number,
}

local MonsterService = {}

MonsterService.monsters = {} :: { [number]: Monster }

-- Hooks wired up by CombatService.
MonsterService.onKilled = nil :: ((monster: Monster, killer: Player?) -> ())?
MonsterService.onAttackPlayer = nil :: ((monster: Monster, player: Player) -> ())?
-- Returns false for players who are not allowed in the zone (they are ignored by its monsters).
MonsterService.canTarget = nil :: ((player: Player, zone: ZonesConfig.Zone) -> boolean)?

local nextId = 1
local rng = Random.new()

local function randomPointIn(zone: ZonesConfig.Zone): Vector3
	local half = zone.Size / 2 - 4
	return Vector3.new(zone.Center.X + rng:NextNumber(-half, half), 0, zone.Center.Z + rng:NextNumber(-half, half))
end

local function groundY(monster: Monster): number
	return MapService.ZoneFloorY + monster.Config.Size.Y / 2
end

local function buildModel(name: string, cfg: MonstersConfig.Monster): (Model, BasePart, Frame)
	local model = Instance.new("Model")
	model.Name = name

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.Size = cfg.Size
	-- Parts are built around the origin facing -Z; PivotTo on the primary part moves the rest along.
	body.CFrame = CFrame.new()
	body.Color = cfg.Color
	body.Material = if name == "Slime" then Enum.Material.Glass else Enum.Material.SmoothPlastic
	body.Transparency = if name == "Slime" then 0.15 else 0
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model
	model.PrimaryPart = body

	-- Two eyes on the front face (-Z) so you can tell which way it is facing.
	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Anchored = true
		eye.CanCollide = false
		eye.CanQuery = false
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * math.max(0.4, cfg.Size.X * 0.18)
		eye.Color = if name == "Skeleton" then Color3.fromRGB(255, 40, 40) else Color3.new(0, 0, 0)
		eye.Material = if name == "Skeleton" then Enum.Material.Neon else Enum.Material.SmoothPlastic
		eye.CFrame = CFrame.new(side * cfg.Size.X * 0.22, cfg.Size.Y * 0.2, -cfg.Size.Z / 2)
		eye.Parent = model
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthGui"
	gui.Size = UDim2.fromOffset(120, 34)
	gui.StudsOffset = Vector3.new(0, cfg.Size.Y / 2 + 1.5, 0)
	gui.MaxDistance = 80
	gui.Adornee = body
	gui.Parent = body

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0.55, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = cfg.Name
	label.Parent = gui

	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, 0.35, 0)
	back.Position = UDim2.fromScale(0, 0.62)
	back.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	back.BorderSizePixel = 0
	back.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
	fill.BorderSizePixel = 0
	fill.Parent = back

	return model, body, fill
end

local function place(monster: Monster)
	local bounce = 0
	if monster.Name == "Slime" then
		bounce = math.abs(math.sin(monster.Phase * 6)) * 0.8
	end
	local position = Vector3.new(monster.Position.X, groundY(monster) + bounce, monster.Position.Z)
	monster.Model:PivotTo(CFrame.lookAt(position, position + monster.Facing))
end

local function spawnMonster(zone: ZonesConfig.Zone)
	local name = Weighted.pick(zone.MonsterWeights, function()
		return rng:NextNumber()
	end)
	local cfg = name and Config.Monsters[name]
	if not name or not cfg then
		return
	end

	local model, body, fill = buildModel(name, cfg)

	local monster: Monster = {
		Id = nextId,
		Name = name,
		Config = cfg,
		Zone = zone,
		Model = model,
		Body = body,
		HealthBar = fill,
		Health = cfg.Health,
		Position = randomPointIn(zone),
		Facing = Vector3.new(0, 0, -1),
		WanderTarget = nil,
		NextWanderAt = 0,
		LastAttackAt = 0,
		Dead = false,
		Phase = rng:NextNumber(0, 10),
	}
	nextId += 1

	model:SetAttribute("MonsterId", monster.Id)
	place(monster)
	model.Parent = MapService.Folders.Monsters
	MonsterService.monsters[monster.Id] = monster
end

local function countInZone(zone: ZonesConfig.Zone): number
	local n = 0
	for _, monster in MonsterService.monsters do
		if monster.Zone == zone then
			n += 1
		end
	end
	return n
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function findTarget(monster: Monster): (Player?, BasePart?)
	local best: Player?, bestRoot: BasePart? = nil, nil
	local bestDistance = monster.Config.AggroRange
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and MapService.isInZone(root.Position, monster.Zone, 2) then
			local canTarget = MonsterService.canTarget
			if not canTarget or canTarget(player, monster.Zone) then
				local distance = (Vector3.new(root.Position.X, 0, root.Position.Z) - monster.Position).Magnitude
				if distance < bestDistance then
					best, bestRoot, bestDistance = player, root, distance
				end
			end
		end
	end
	return best, bestRoot
end

local function clampToZone(position: Vector3, zone: ZonesConfig.Zone): Vector3
	local half = zone.Size / 2 - 2
	return Vector3.new(
		math.clamp(position.X, zone.Center.X - half, zone.Center.X + half),
		0,
		math.clamp(position.Z, zone.Center.Z - half, zone.Center.Z + half)
	)
end

local function moveToward(monster: Monster, target: Vector3, speed: number, dt: number, stopDistance: number)
	local offset = Vector3.new(target.X - monster.Position.X, 0, target.Z - monster.Position.Z)
	local distance = offset.Magnitude
	if distance < 0.05 then
		return
	end
	monster.Facing = offset.Unit
	if distance <= stopDistance then
		return
	end
	local step = math.min(speed * dt, distance - stopDistance)
	monster.Position = clampToZone(monster.Position + offset.Unit * step, monster.Zone)
end

local function step(monster: Monster, dt: number, now: number)
	monster.Phase += dt
	local cfg = monster.Config
	local player, root = findTarget(monster)
	if player and root then
		local reach = cfg.AttackRange + cfg.Size.X / 2
		moveToward(monster, root.Position, cfg.Speed, dt, reach * 0.7)
		local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
		if (flat - monster.Position).Magnitude <= reach and now - monster.LastAttackAt >= cfg.AttackCooldown then
			monster.LastAttackAt = now
			local hook = MonsterService.onAttackPlayer
			if hook then
				task.spawn(hook, monster, player)
			end
		end
		monster.WanderTarget = nil
	else
		if not monster.WanderTarget or now >= monster.NextWanderAt then
			monster.WanderTarget = randomPointIn(monster.Zone)
			monster.NextWanderAt = now + rng:NextNumber(3, 7)
		end
		local target = monster.WanderTarget :: Vector3
		moveToward(monster, target, cfg.Speed * 0.35, dt, 0.5)
	end
	place(monster)
end

local function flash(monster: Monster)
	local body = monster.Body
	local original = monster.Config.Color
	body.Color = Color3.new(1, 1, 1)
	task.delay(0.08, function()
		if body.Parent then
			body.Color = original
		end
	end)
end

function MonsterService.damage(monster: Monster, amount: number, attacker: Player?)
	if monster.Dead then
		return
	end
	monster.Health -= amount
	monster.HealthBar.Size = UDim2.fromScale(math.clamp(monster.Health / monster.Config.Health, 0, 1), 1)
	flash(monster)
	if monster.Health > 0 then
		return
	end

	monster.Dead = true
	MonsterService.monsters[monster.Id] = nil
	local hook = MonsterService.onKilled
	if hook then
		task.spawn(hook, monster, attacker)
	end
	monster.Model:Destroy()

	task.delay(monster.Zone.RespawnTime, function()
		if countInZone(monster.Zone) < monster.Zone.MaxMonsters then
			spawnMonster(monster.Zone)
		end
	end)
end

function MonsterService.worldPosition(monster: Monster): Vector3
	return Vector3.new(monster.Position.X, groundY(monster), monster.Position.Z)
end

function MonsterService.init()
	for _, zone in Config.Zones do
		for _ = 1, zone.MaxMonsters do
			spawnMonster(zone)
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, monster in MonsterService.monsters do
			step(monster, dt, now)
		end
	end)
end

return MonsterService
