--!strict
-- Zones are axis-aligned squares on the ground (Y = 0). Monsters never leave their zone.
-- MonsterWeights picks which monster spawns; EggWeights picks the rarity of eggs dropped in the zone.

export type Zone = {
	Id: string,
	Name: string,
	LevelRequired: number,
	Center: Vector3,
	Size: number,
	GroundColor: Color3,
	MaxMonsters: number,
	RespawnTime: number,
	MonsterWeights: { [string]: number },
	EggWeights: { [string]: number },
}

local Zones: { Zone } = {
	{
		Id = "Meadow",
		Name = "Slime Meadow",
		LevelRequired = 1,
		Center = Vector3.new(120, 0, 0),
		Size = 110,
		GroundColor = Color3.fromRGB(110, 170, 80),
		MaxMonsters = 8,
		RespawnTime = 4,
		MonsterWeights = { Slime = 70, Goblin = 30 },
		EggWeights = { Common = 80, Rare = 17, Epic = 3 },
	},
	{
		Id = "Graveyard",
		Name = "Haunted Graveyard",
		LevelRequired = 5,
		Center = Vector3.new(250, 0, 0),
		Size = 110,
		GroundColor = Color3.fromRGB(70, 60, 80),
		MaxMonsters = 7,
		RespawnTime = 6,
		MonsterWeights = { Skeleton = 75, Ogre = 25 },
		EggWeights = { Common = 40, Rare = 38, Epic = 18, Legendary = 4 },
	},
}

return Zones
