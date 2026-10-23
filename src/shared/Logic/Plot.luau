--!strict
local Config = require(script.Parent.Parent.Config)
local Pets = require(script.Parent.Pets)
local Types = require(script.Parent.Types)
local Weighted = require(script.Parent.Weighted)

local Plot = {}

-- Fraction grown in [0, 1]. `now` is unix time, so time spent offline counts.
function Plot.progress(slot: Types.SlotData, now: number): number
	if slot.GrowTime <= 0 then
		return 1
	end
	return math.clamp((now - slot.PlantedAt) / slot.GrowTime, 0, 1)
end

function Plot.secondsLeft(slot: Types.SlotData, now: number): number
	return math.max(0, math.ceil(slot.PlantedAt + slot.GrowTime - now))
end

function Plot.isReady(slot: Types.SlotData, now: number): boolean
	return now >= slot.PlantedAt + slot.GrowTime
end

function Plot.nextSlotPrice(data: Types.PlayerData): number?
	if data.UnlockedSlots >= Config.Plots.MaxSlots then
		return nil
	end
	return Config.Plots.SlotPrices[data.UnlockedSlots + 1]
end

function Plot.buySlot(data: Types.PlayerData): (boolean, string)
	local price = Plot.nextSlotPrice(data)
	if price == nil then
		return false, "All slots are unlocked"
	end
	if data.Coins < price then
		return false, `Unlocking a slot costs {price} coins`
	end
	data.Coins -= price
	data.UnlockedSlots += 1
	return true, `Unlocked slot {data.UnlockedSlots}`
end

function Plot.addEgg(data: Types.PlayerData, rarity: string): boolean
	if not Config.Eggs[rarity] then
		return false
	end
	local total = 0
	for _, count in data.Eggs do
		total += count
	end
	if total >= Config.Economy.MaxEggs then
		return false
	end
	data.Eggs[rarity] = (data.Eggs[rarity] or 0) + 1
	return true
end

function Plot.plant(data: Types.PlayerData, slotIndex: number, rarity: string, now: number): (boolean, string)
	local egg = Config.Eggs[rarity]
	if not egg then
		return false, "Unknown egg"
	end
	if slotIndex < 1 or slotIndex > data.UnlockedSlots or slotIndex ~= math.floor(slotIndex) then
		return false, "That slot is locked"
	end
	local key = tostring(slotIndex)
	if data.Plot[key] then
		return false, "That slot is already in use"
	end
	if (data.Eggs[rarity] or 0) <= 0 then
		return false, `You have no {rarity} eggs`
	end
	data.Eggs[rarity] -= 1
	if data.Eggs[rarity] <= 0 then
		data.Eggs[rarity] = nil
	end
	data.Plot[key] = { Rarity = rarity, PlantedAt = now, GrowTime = egg.GrowTime }
	return true, `Planted a {rarity} egg`
end

-- Hatches a fully grown egg into a pet. Returns the new pet's uid and pet id on success.
function Plot.hatch(
	data: Types.PlayerData,
	slotIndex: number,
	now: number,
	rng: Types.Rng
): (boolean, string, string?, string?)
	local key = tostring(slotIndex)
	local slot = data.Plot[key]
	if not slot then
		return false, "Nothing is planted there", nil, nil
	end
	if not Plot.isReady(slot, now) then
		return false, `Ready in {Plot.secondsLeft(slot, now)}s`, nil, nil
	end
	if Pets.count(data) >= Config.Economy.MaxPets then
		return false, "Your pet inventory is full", nil, nil
	end
	local egg = Config.Eggs[slot.Rarity]
	local petId = egg and Weighted.pick(egg.PetWeights, rng)
	if petId == nil or Config.Pets[petId] == nil then
		return false, "This egg is broken", nil, nil
	end
	data.Plot[key] = nil
	local uid = Pets.add(data, petId)
	data.Stats.EggsHatched += 1
	return true, `Hatched a {Config.Pets[petId].Name}!`, uid, petId
end

-- Picks the rarest egg the player owns, for one-click planting.
function Plot.bestEgg(data: Types.PlayerData): string?
	local best: string? = nil
	local bestOrder = -math.huge
	for rarity, count in data.Eggs do
		local egg = Config.Eggs[rarity]
		if count > 0 and egg and egg.Order > bestOrder then
			best = rarity
			bestOrder = egg.Order
		end
	end
	return best
end

return Plot
