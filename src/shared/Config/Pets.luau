--!strict
-- Each pet boosts either Damage or Coins by Boost (0.1 = +10%) at stage 1.
-- Evolving multiplies that boost by Evolution.StageMultipliers[stage].
-- Boosts from all equipped pets add together.

export type Pet = {
	Id: string,
	Name: string,
	Rarity: string,
	BoostType: "Damage" | "Coins",
	Boost: number,
	Color: Color3,
	Size: number,
}

export type Evolution = {
	MaxStage: number,
	StageNames: { string },
	StageMultipliers: { number },
	MergeCount: number,
	FeedCostBase: { [string]: number },
	FeedCostStageMultiplier: number,
	MaxEquipped: number,
}

local Pets: { [string]: Pet } = {
	Puppy = {
		Id = "Puppy",
		Name = "Puppy",
		Rarity = "Common",
		BoostType = "Damage",
		Boost = 0.1,
		Color = Color3.fromRGB(200, 150, 100),
		Size = 1.5,
	},
	Kitty = {
		Id = "Kitty",
		Name = "Kitty",
		Rarity = "Common",
		BoostType = "Coins",
		Boost = 0.1,
		Color = Color3.fromRGB(255, 170, 60),
		Size = 1.5,
	},
	Bunny = {
		Id = "Bunny",
		Name = "Bunny",
		Rarity = "Common",
		BoostType = "Coins",
		Boost = 0.15,
		Color = Color3.fromRGB(250, 220, 230),
		Size = 1.4,
	},
	Fox = {
		Id = "Fox",
		Name = "Fox",
		Rarity = "Rare",
		BoostType = "Damage",
		Boost = 0.25,
		Color = Color3.fromRGB(230, 110, 30),
		Size = 1.7,
	},
	Owl = {
		Id = "Owl",
		Name = "Owl",
		Rarity = "Rare",
		BoostType = "Coins",
		Boost = 0.3,
		Color = Color3.fromRGB(140, 110, 80),
		Size = 1.6,
	},
	Wolf = {
		Id = "Wolf",
		Name = "Wolf",
		Rarity = "Epic",
		BoostType = "Damage",
		Boost = 0.5,
		Color = Color3.fromRGB(120, 120, 140),
		Size = 2,
	},
	Unicorn = {
		Id = "Unicorn",
		Name = "Unicorn",
		Rarity = "Epic",
		BoostType = "Coins",
		Boost = 0.6,
		Color = Color3.fromRGB(255, 160, 240),
		Size = 2,
	},
	Dragon = {
		Id = "Dragon",
		Name = "Dragon",
		Rarity = "Legendary",
		BoostType = "Damage",
		Boost = 1.0,
		Color = Color3.fromRGB(200, 30, 30),
		Size = 2.4,
	},
}

local Evolution: Evolution = {
	MaxStage = 3,
	StageNames = { "Normal", "Golden", "Rainbow" },
	StageMultipliers = { 1, 2.5, 6 },
	-- Merging consumes this many pets of the same type and stage and returns one pet a stage higher.
	MergeCount = 3,
	-- Feeding costs FeedCostBase[rarity] * FeedCostStageMultiplier ^ (stage - 1) coins.
	FeedCostBase = { Common = 500, Rare = 2000, Epic = 8000, Legendary = 30000 },
	FeedCostStageMultiplier = 4,
	MaxEquipped = 3,
}

return {
	Pets = Pets,
	Evolution = Evolution,
}
