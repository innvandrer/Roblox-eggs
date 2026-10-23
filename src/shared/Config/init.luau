--!strict
-- All balancing data lives in this folder. Gameplay code reads it through this module.

local Armor = require(script.Armor)
local Eggs = require(script.Eggs)
local Monsters = require(script.Monsters)
local Pets = require(script.Pets)
local Progression = require(script.Progression)
local Weapons = require(script.Weapons)
local Zones = require(script.Zones)

return {
	Weapons = Weapons,
	Armor = Armor,
	Monsters = Monsters,
	Zones = Zones,
	Eggs = Eggs,
	Pets = Pets.Pets,
	Evolution = Pets.Evolution,
	Leveling = Progression.Leveling,
	Plots = Progression.Plots,
	Economy = Progression.Economy,
}
