--!strict
local Config = require(script.Parent.Parent.Config)
local Leveling = require(script.Parent.Leveling)
local Pets = require(script.Parent.Pets)
local Plot = require(script.Parent.Plot)
local Types = require(script.Parent.Types)
local Weighted = require(script.Parent.Weighted)
local ZonesConfig = require(script.Parent.Parent.Config.Zones)

export type KillResult = {
	Coins: number,
	XP: number,
	LevelsGained: number,
	Egg: string?,
	EggLost: boolean,
}

local Rewards = {}

-- Applies the rewards for killing `monsterName` inside `zone` to `data`.
function Rewards.applyKill(
	data: Types.PlayerData,
	monsterName: string,
	zone: ZonesConfig.Zone,
	rng: Types.Rng
): KillResult
	local monster = Config.Monsters[monsterName]
	assert(monster, "Unknown monster " .. monsterName)
	local multipliers = Pets.getMultipliers(data)

	local coins = math.floor(monster.Coins * multipliers.Coins + 0.5)
	data.Coins += coins
	data.Stats.Kills += 1
	local levelsGained = Leveling.addXp(data, monster.XP)

	local egg: string? = nil
	local eggLost = false
	if rng() < monster.EggChance then
		egg = Weighted.pick(zone.EggWeights, rng)
		if egg and not Plot.addEgg(data, egg) then
			eggLost = true
		end
	end

	return {
		Coins = coins,
		XP = monster.XP,
		LevelsGained = levelsGained,
		Egg = egg,
		EggLost = eggLost,
	}
end

return Rewards
