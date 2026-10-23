--!strict
-- DamageReduction is a fraction (0.2 = take 20% less damage from monsters).

export type Armor = {
	Id: string,
	Name: string,
	HealthBonus: number,
	DamageReduction: number,
	Price: number,
	LevelRequired: number,
	Color: Color3,
}

local Armor: { Armor } = {
	{
		Id = "LeatherArmor",
		Name = "Leather Armor",
		HealthBonus = 25,
		DamageReduction = 0.1,
		Price = 200,
		LevelRequired = 2,
		Color = Color3.fromRGB(120, 80, 45),
	},
	{
		Id = "ChainArmor",
		Name = "Chainmail",
		HealthBonus = 60,
		DamageReduction = 0.2,
		Price = 1200,
		LevelRequired = 5,
		Color = Color3.fromRGB(160, 160, 170),
	},
	{
		Id = "PlateArmor",
		Name = "Plate Armor",
		HealthBonus = 120,
		DamageReduction = 0.35,
		Price = 5000,
		LevelRequired = 8,
		Color = Color3.fromRGB(230, 200, 90),
	},
}

return Armor
