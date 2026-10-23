--!strict
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Types)

local function create(): Types.PlayerData
	local starter = Config.Weapons[1]
	return {
		Coins = Config.Economy.StartingCoins,
		Level = 1,
		XP = 0,
		OwnedWeapons = { [starter.Id] = true },
		EquippedWeapon = starter.Id,
		OwnedArmor = {},
		EquippedArmor = "",
		Eggs = {},
		UnlockedSlots = Config.Plots.StartingSlots,
		Plot = {},
		Pets = {},
		EquippedPets = {},
		NextPetId = 1,
		Stats = {
			Kills = 0,
			EggsHatched = 0,
			PetsEvolved = 0,
		},
	}
end

return {
	create = create,
}
