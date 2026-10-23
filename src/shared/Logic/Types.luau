--!strict

export type PetData = {
	Id: string,
	Stage: number,
}

export type SlotData = {
	Rarity: string,
	-- Unix time (os.time) when planted; growth is based on wall-clock time so it continues offline.
	PlantedAt: number,
	GrowTime: number,
}

export type Stats = {
	Kills: number,
	EggsHatched: number,
	PetsEvolved: number,
}

export type PlayerData = {
	Coins: number,
	Level: number,
	XP: number,
	OwnedWeapons: { [string]: boolean },
	EquippedWeapon: string,
	OwnedArmor: { [string]: boolean },
	-- Empty string means no armor equipped.
	EquippedArmor: string,
	Eggs: { [string]: number },
	UnlockedSlots: number,
	-- Keyed by slot number as a string ("1".."8") so the table saves cleanly to DataStores.
	Plot: { [string]: SlotData },
	-- Keyed by a unique pet id string.
	Pets: { [string]: PetData },
	EquippedPets: { string },
	NextPetId: number,
	Stats: Stats,
}

export type Rng = () -> number

export type Multipliers = {
	Damage: number,
	Coins: number,
}

return {}
