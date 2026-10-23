--!strict
-- XP needed to go from level L to L+1 is floor(XpBase * L ^ XpExponent).

export type Leveling = {
	MaxLevel: number,
	XpBase: number,
	XpExponent: number,
	BaseHealth: number,
	HealthPerLevel: number,
	BaseDamage: number,
	DamagePerLevel: number,
}

export type Plots = {
	StartingSlots: number,
	MaxSlots: number,
	-- SlotPrices[n] is the price of unlocking slot n.
	SlotPrices: { [number]: number },
}

export type Economy = {
	StartingCoins: number,
	MaxEggs: number,
	MaxPets: number,
}

local Leveling: Leveling = {
	MaxLevel = 50,
	XpBase = 50,
	XpExponent = 1.5,
	BaseHealth = 100,
	HealthPerLevel = 10,
	BaseDamage = 0,
	DamagePerLevel = 2,
}

local Plots: Plots = {
	StartingSlots = 3,
	MaxSlots = 8,
	SlotPrices = {
		[4] = 250,
		[5] = 750,
		[6] = 2000,
		[7] = 5000,
		[8] = 12000,
	},
}

local Economy: Economy = {
	StartingCoins = 0,
	MaxEggs = 100,
	MaxPets = 60,
}

return {
	Leveling = Leveling,
	Plots = Plots,
	Economy = Economy,
}
