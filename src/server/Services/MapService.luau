--!strict
-- Builds the placeholder map out of parts: spawn, shop stand, monster zones and base plots.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ZonesConfig = require(ReplicatedStorage.Shared.Config.Zones)

local MapService = {}

-- Ground top surface is at Y = 0.
MapService.SpawnPosition = Vector3.new(0, 3, 0)
MapService.ZoneFloorY = 0.2
MapService.PlotSize = 44
MapService.SlotColumns = 4
MapService.SlotSpacing = 10
MapService.PlotOrigins = {
	Vector3.new(-90, 0, -55),
	Vector3.new(-90, 0, 0),
	Vector3.new(-90, 0, 55),
	Vector3.new(-145, 0, -55),
	Vector3.new(-145, 0, 0),
	Vector3.new(-145, 0, 55),
}

export type PlotModel = {
	Index: number,
	Model: Model,
	Base: BasePart,
	Sign: TextLabel,
	Pads: { BasePart },
}

MapService.Plots = {} :: { PlotModel }
MapService.Folders = {} :: { [string]: Folder }

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function billboard(parent: Instance, text: string, studsOffset: Vector3, size: UDim2?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = size or UDim2.fromOffset(240, 50)
	gui.StudsOffset = studsOffset
	gui.AlwaysOnTop = false
	gui.MaxDistance = 150
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	return label
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	MapService.Folders[name] = f
	return f
end

local function buildSpawn(map: Folder)
	part({
		Name = "Baseplate",
		Size = Vector3.new(760, 2, 420),
		Position = Vector3.new(60, -1, 0),
		Color = Color3.fromRGB(95, 150, 75),
		Material = Enum.Material.Grass,
		Parent = map,
	})

	part({
		Name = "SpawnArea",
		Size = Vector3.new(56, 0.2, 56),
		Position = Vector3.new(0, 0.1, 0),
		Color = Color3.fromRGB(200, 195, 180),
		Material = Enum.Material.Slate,
		Parent = map,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.5, 0)
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = map

	-- Paths from spawn to the zones and the plots.
	part({
		Name = "PathEast",
		Size = Vector3.new(40, 0.15, 10),
		Position = Vector3.new(46, 0.075, 0),
		Color = Color3.fromRGB(170, 150, 110),
		Material = Enum.Material.Sand,
		Parent = map,
	})
	part({
		Name = "PathWest",
		Size = Vector3.new(36, 0.15, 10),
		Position = Vector3.new(-44, 0.075, 0),
		Color = Color3.fromRGB(170, 150, 110),
		Material = Enum.Material.Sand,
		Parent = map,
	})

	-- Shop stand. The client opens the shop menu when this prompt is triggered.
	local counter = part({
		Name = "ShopCounter",
		Size = Vector3.new(12, 3.5, 3),
		Position = Vector3.new(0, 1.75, -20),
		Color = Color3.fromRGB(140, 90, 50),
		Material = Enum.Material.WoodPlanks,
		Parent = map,
	})
	part({
		Name = "ShopRoof",
		Size = Vector3.new(14, 0.6, 6),
		Position = Vector3.new(0, 8, -21),
		Color = Color3.fromRGB(200, 60, 60),
		Parent = map,
	})
	for _, x in { -6, 6 } do
		part({
			Name = "ShopPost",
			Size = Vector3.new(0.6, 8, 0.6),
			Position = Vector3.new(x, 4, -23),
			Color = Color3.fromRGB(110, 70, 40),
			Parent = map,
		})
	end
	billboard(counter, "Gear Shop", Vector3.new(0, 8, 0))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Shop"
	prompt.ObjectText = "Gear Shop"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpensMenu", "Shop")
	prompt.Parent = counter
end

local function buildZone(map: Folder, zone: ZonesConfig.Zone)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zone.Id
	zoneFolder.Parent = map

	local floor = part({
		Name = "Floor",
		Size = Vector3.new(zone.Size, MapService.ZoneFloorY, zone.Size),
		Position = Vector3.new(zone.Center.X, MapService.ZoneFloorY / 2, zone.Center.Z),
		Color = zone.GroundColor,
		Material = Enum.Material.Ground,
		Parent = zoneFolder,
	})
	local signText = if zone.LevelRequired > 1 then `{zone.Name}\nLevel {zone.LevelRequired}+` else zone.Name
	local signPost = part({
		Name = "Sign",
		Size = Vector3.new(1, 6, 1),
		Position = Vector3.new(zone.Center.X - zone.Size / 2 - 3, 3, zone.Center.Z + 8),
		Color = Color3.fromRGB(110, 70, 40),
		Parent = zoneFolder,
	})
	billboard(signPost, signText, Vector3.new(0, 5, 0), UDim2.fromOffset(260, 70))
	floor:SetAttribute("ZoneId", zone.Id)

	-- Walls start non-collidable on the server; each client turns them solid locally while the
	-- player is below the zone's level. The server also teleports out anyone who slips through.
	if zone.LevelRequired > 1 then
		local half = zone.Size / 2
		local height = 14
		local walls = {
			{ Vector3.new(zone.Size, height, 1), Vector3.new(0, 0, -half) },
			{ Vector3.new(zone.Size, height, 1), Vector3.new(0, 0, half) },
			{ Vector3.new(1, height, zone.Size), Vector3.new(-half, 0, 0) },
			{ Vector3.new(1, height, zone.Size), Vector3.new(half, 0, 0) },
		}
		for _, def in walls do
			local wall = part({
				Name = "LevelWall",
				Size = def[1],
				Position = Vector3.new(zone.Center.X, height / 2, zone.Center.Z) + def[2],
				Color = Color3.fromRGB(255, 80, 80),
				Material = Enum.Material.ForceField,
				Transparency = 0.4,
				CanCollide = false,
				CastShadow = false,
				Parent = zoneFolder,
			})
			wall:SetAttribute("LevelRequired", zone.LevelRequired)
			CollectionService:AddTag(wall, "LevelWall")
		end
	end
end

-- Pad positions are laid out in rows of SlotColumns, centered on the plot.
function MapService.slotOffset(slotIndex: number): Vector3
	local columns = MapService.SlotColumns
	local rows = math.ceil(Config.Plots.MaxSlots / columns)
	local col = (slotIndex - 1) % columns
	local row = (slotIndex - 1) // columns
	local spacing = MapService.SlotSpacing
	return Vector3.new((col - (columns - 1) / 2) * spacing, 0, (row - (rows - 1) / 2) * spacing + 4)
end

local function buildPlot(plotsFolder: Folder, index: number, origin: Vector3): PlotModel
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)

	local base = part({
		Name = "Base",
		Size = Vector3.new(MapService.PlotSize, 0.4, MapService.PlotSize),
		Position = origin + Vector3.new(0, 0.2, 0),
		Color = Color3.fromRGB(120, 90, 60),
		Material = Enum.Material.Ground,
		Parent = model,
	})
	model.PrimaryPart = base

	local signPost = part({
		Name = "Sign",
		Size = Vector3.new(8, 4, 0.5),
		Position = origin + Vector3.new(0, 2.4, -MapService.PlotSize / 2 + 2),
		Color = Color3.fromRGB(240, 230, 200),
		Parent = model,
	})
	local sign = billboard(signPost, "Free Plot", Vector3.new(0, 4, 0), UDim2.fromOffset(260, 50))

	local pads: { BasePart } = {}
	for slot = 1, Config.Plots.MaxSlots do
		local pad = part({
			Name = "Slot" .. slot,
			Size = Vector3.new(6, 0.6, 6),
			Position = origin + MapService.slotOffset(slot) + Vector3.new(0, 0.5, 0),
			Color = Color3.fromRGB(80, 60, 40),
			Material = Enum.Material.Mud,
			Parent = model,
		})
		pad:SetAttribute("Slot", slot)
		pads[slot] = pad
	end

	model.Parent = plotsFolder
	return {
		Index = index,
		Model = model,
		Base = base,
		Sign = sign,
		Pads = pads,
	}
end

function MapService.build()
	local map = folder("Map", workspace)
	folder("Monsters", workspace)
	folder("Pets", workspace)
	folder("Effects", workspace)
	local plotsFolder = folder("Plots", workspace)

	buildSpawn(map)
	for _, zone in Config.Zones do
		buildZone(map, zone)
	end
	for index, origin in MapService.PlotOrigins do
		MapService.Plots[index] = buildPlot(plotsFolder, index, origin)
	end
end

function MapService.isInZone(position: Vector3, zone: ZonesConfig.Zone, margin: number?): boolean
	local half = zone.Size / 2 + (margin or 0)
	return math.abs(position.X - zone.Center.X) <= half and math.abs(position.Z - zone.Center.Z) <= half
end

function MapService.zoneAt(position: Vector3): ZonesConfig.Zone?
	for _, zone in Config.Zones do
		if MapService.isInZone(position, zone) then
			return zone
		end
	end
	return nil
end

return MapService
