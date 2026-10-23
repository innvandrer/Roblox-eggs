--!strict
-- GrowTime is in seconds and keeps counting while the player is offline.
-- PetWeights decides which pet hatches from an egg of this rarity.

export type Egg = {
	Rarity: string,
	Order: number,
	GrowTime: number,
	Color: Color3,
	PetWeights: { [string]: number },
}

local Eggs: { [string]: Egg } = {
	Common = {
		Rarity = "Common",
		Order = 1,
		GrowTime = 60,
		Color = Color3.fromRGB(235, 235, 235),
		PetWeights = { Puppy = 45, Kitty = 45, Bunny = 10 },
	},
	Rare = {
		Rarity = "Rare",
		Order = 2,
		GrowTime = 180,
		Color = Color3.fromRGB(80, 150, 255),
		PetWeights = { Bunny = 30, Fox = 40, Owl = 30 },
	},
	Epic = {
		Rarity = "Epic",
		Order = 3,
		GrowTime = 600,
		Color = Color3.fromRGB(170, 80, 255),
		PetWeights = { Owl = 20, Wolf = 45, Unicorn = 35 },
	},
	Legendary = {
		Rarity = "Legendary",
		Order = 4,
		GrowTime = 1800,
		Color = Color3.fromRGB(255, 190, 40),
		PetWeights = { Unicorn = 40, Dragon = 60 },
	},
}

return Eggs
