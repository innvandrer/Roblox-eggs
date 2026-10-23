--!strict
-- Order controls how the shop lists items. Range is in studs, Cooldown in seconds.

export type Weapon = {
	Id: string,
	Name: string,
	Damage: number,
	Cooldown: number,
	Range: number,
	Price: number,
	LevelRequired: number,
	Color: Color3,
	Length: number,
}

local Weapons: { Weapon } = {
	{
		Id = "WoodenSword",
		Name = "Wooden Sword",
		Damage = 10,
		Cooldown = 0.6,
		Range = 7,
		Price = 0,
		LevelRequired = 1,
		Color = Color3.fromRGB(150, 105, 60),
		Length = 3,
	},
	{
		Id = "StoneSword",
		Name = "Stone Sword",
		Damage = 18,
		Cooldown = 0.6,
		Range = 7,
		Price = 150,
		LevelRequired = 2,
		Color = Color3.fromRGB(130, 130, 130),
		Length = 3.5,
	},
	{
		Id = "IronSword",
		Name = "Iron Sword",
		Damage = 30,
		Cooldown = 0.55,
		Range = 8,
		Price = 600,
		LevelRequired = 4,
		Color = Color3.fromRGB(200, 200, 210),
		Length = 4,
	},
	{
		Id = "CrystalBlade",
		Name = "Crystal Blade",
		Damage = 55,
		Cooldown = 0.5,
		Range = 8,
		Price = 2500,
		LevelRequired = 7,
		Color = Color3.fromRGB(110, 220, 255),
		Length = 4.5,
	},
	{
		Id = "DragonSlayer",
		Name = "Dragon Slayer",
		Damage = 100,
		Cooldown = 0.7,
		Range = 10,
		Price = 9000,
		LevelRequired = 10,
		Color = Color3.fromRGB(220, 60, 40),
		Length = 5.5,
	},
}

return Weapons
