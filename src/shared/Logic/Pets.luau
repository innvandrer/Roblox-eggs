--!strict
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Types)

local Pets = {}

function Pets.count(data: Types.PlayerData): number
	local n = 0
	for _ in data.Pets do
		n += 1
	end
	return n
end

function Pets.isEquipped(data: Types.PlayerData, uid: string): boolean
	return table.find(data.EquippedPets, uid) ~= nil
end

-- Adds a new stage-1 pet and returns its unique id.
function Pets.add(data: Types.PlayerData, petId: string, stage: number?): string
	assert(Config.Pets[petId], "Unknown pet " .. petId)
	local uid = tostring(data.NextPetId)
	data.NextPetId += 1
	data.Pets[uid] = { Id = petId, Stage = stage or 1 }
	return uid
end

local function remove(data: Types.PlayerData, uid: string)
	data.Pets[uid] = nil
	local index = table.find(data.EquippedPets, uid)
	if index then
		table.remove(data.EquippedPets, index)
	end
end

function Pets.equip(data: Types.PlayerData, uid: string): (boolean, string)
	if not data.Pets[uid] then
		return false, "Unknown pet"
	end
	if Pets.isEquipped(data, uid) then
		return false, "Already equipped"
	end
	if #data.EquippedPets >= Config.Evolution.MaxEquipped then
		return false, `You can only equip {Config.Evolution.MaxEquipped} pets`
	end
	table.insert(data.EquippedPets, uid)
	return true, "Pet equipped"
end

function Pets.unequip(data: Types.PlayerData, uid: string): (boolean, string)
	local index = table.find(data.EquippedPets, uid)
	if not index then
		return false, "Pet is not equipped"
	end
	table.remove(data.EquippedPets, index)
	return true, "Pet unequipped"
end

-- Drops equipped ids that no longer point at an owned pet (keeps old saves consistent).
function Pets.sanitize(data: Types.PlayerData)
	local seen: { [string]: boolean } = {}
	local cleaned = {}
	for _, uid in data.EquippedPets do
		if data.Pets[uid] and not seen[uid] and #cleaned < Config.Evolution.MaxEquipped then
			seen[uid] = true
			table.insert(cleaned, uid)
		end
	end
	data.EquippedPets = cleaned
end

function Pets.boostOf(pet: Types.PetData): number
	local cfg = Config.Pets[pet.Id]
	if not cfg then
		return 0
	end
	local multiplier = Config.Evolution.StageMultipliers[pet.Stage] or 1
	return cfg.Boost * multiplier
end

function Pets.getMultipliers(data: Types.PlayerData): Types.Multipliers
	local result: Types.Multipliers = { Damage = 1, Coins = 1 }
	for _, uid in data.EquippedPets do
		local pet = data.Pets[uid]
		local cfg = pet and Config.Pets[pet.Id]
		if pet and cfg then
			if cfg.BoostType == "Damage" then
				result.Damage += Pets.boostOf(pet)
			else
				result.Coins += Pets.boostOf(pet)
			end
		end
	end
	return result
end

function Pets.feedCost(pet: Types.PetData): number?
	local evolution = Config.Evolution
	if pet.Stage >= evolution.MaxStage then
		return nil
	end
	local cfg = Config.Pets[pet.Id]
	if not cfg then
		return nil
	end
	local base = evolution.FeedCostBase[cfg.Rarity] or 0
	return math.floor(base * evolution.FeedCostStageMultiplier ^ (pet.Stage - 1))
end

function Pets.feed(data: Types.PlayerData, uid: string): (boolean, string)
	local pet = data.Pets[uid]
	if not pet then
		return false, "Unknown pet"
	end
	local cost = Pets.feedCost(pet)
	if cost == nil then
		return false, "Pet is already fully evolved"
	end
	if data.Coins < cost then
		return false, `Feeding costs {cost} coins`
	end
	data.Coins -= cost
	pet.Stage += 1
	data.Stats.PetsEvolved += 1
	return true, `{Config.Pets[pet.Id].Name} evolved to {Config.Evolution.StageNames[pet.Stage]}!`
end

-- Returns the uids that a merge starting from `uid` would consume (including `uid`), or nil.
-- Unequipped pets are used before equipped ones.
function Pets.findMergeGroup(data: Types.PlayerData, uid: string): { string }?
	local pet = data.Pets[uid]
	if not pet or pet.Stage >= Config.Evolution.MaxStage then
		return nil
	end
	local candidates = {}
	for otherUid, other in data.Pets do
		if otherUid ~= uid and other.Id == pet.Id and other.Stage == pet.Stage then
			table.insert(candidates, otherUid)
		end
	end
	table.sort(candidates, function(a, b)
		local aEquipped = Pets.isEquipped(data, a)
		local bEquipped = Pets.isEquipped(data, b)
		if aEquipped ~= bEquipped then
			return not aEquipped
		end
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	local needed = Config.Evolution.MergeCount - 1
	if #candidates < needed then
		return nil
	end
	local group = { uid }
	for i = 1, needed do
		table.insert(group, candidates[i])
	end
	return group
end

-- Merges `uid` with matching pets into one pet a stage higher. Returns the new pet's uid on success.
function Pets.merge(data: Types.PlayerData, uid: string): (boolean, string, string?)
	local pet = data.Pets[uid]
	if not pet then
		return false, "Unknown pet", nil
	end
	if pet.Stage >= Config.Evolution.MaxStage then
		return false, "Pet is already fully evolved", nil
	end
	local group = Pets.findMergeGroup(data, uid)
	if not group then
		return false, `You need {Config.Evolution.MergeCount} of the same pet at the same stage`, nil
	end
	local wasEquipped = Pets.isEquipped(data, uid)
	local petId, stage = pet.Id, pet.Stage + 1
	for _, consumed in group do
		remove(data, consumed)
	end
	local newUid = Pets.add(data, petId, stage)
	if wasEquipped then
		Pets.equip(data, newUid)
	end
	data.Stats.PetsEvolved += 1
	return true, `Merged into a {Config.Evolution.StageNames[stage]} {Config.Pets[petId].Name}!`, newUid
end

return Pets
