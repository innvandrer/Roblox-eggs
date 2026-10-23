--!strict
local Config = require(script.Parent.Parent.Config)
local Gear = require(script.Parent.Gear)
local Types = require(script.Parent.Types)

local Leveling = {}

function Leveling.xpToNext(level: number): number
	local cfg = Config.Leveling
	return math.floor(cfg.XpBase * level ^ cfg.XpExponent)
end

-- Adds XP and applies any level-ups. Returns how many levels were gained.
function Leveling.addXp(data: Types.PlayerData, amount: number): number
	local cfg = Config.Leveling
	local gained = 0
	if data.Level >= cfg.MaxLevel then
		data.XP = 0
		return 0
	end
	data.XP += math.max(0, math.floor(amount))
	while data.Level < cfg.MaxLevel and data.XP >= Leveling.xpToNext(data.Level) do
		data.XP -= Leveling.xpToNext(data.Level)
		data.Level += 1
		gained += 1
	end
	if data.Level >= cfg.MaxLevel then
		data.XP = 0
	end
	return gained
end

function Leveling.maxHealth(data: Types.PlayerData): number
	local cfg = Config.Leveling
	local health = cfg.BaseHealth + (data.Level - 1) * cfg.HealthPerLevel
	local armor = Gear.getArmor(data.EquippedArmor)
	if armor then
		health += armor.HealthBonus
	end
	return health
end

function Leveling.baseDamage(level: number): number
	local cfg = Config.Leveling
	return cfg.BaseDamage + (level - 1) * cfg.DamagePerLevel
end

return Leveling
