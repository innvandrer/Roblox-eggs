-- Run with: lune run tests/run.luau  (from the repo root)
local process = require("@lune/process")

local t = require("./harness")

local Config = t.require("src/shared/Config")
local DataTemplate = t.require("src/shared/Logic/DataTemplate")
local Gear = t.require("src/shared/Logic/Gear")
local Leveling = t.require("src/shared/Logic/Leveling")
local Pets = t.require("src/shared/Logic/Pets")
local Plot = t.require("src/shared/Logic/Plot")
local Rewards = t.require("src/shared/Logic/Rewards")
local Weighted = t.require("src/shared/Logic/Weighted")

local function fresh()
	return DataTemplate.create()
end

print("Config")

t.test("every weighted table points at real entries", function()
	for _, zone in Config.Zones do
		for name in zone.MonsterWeights do
			t.truthy(Config.Monsters[name], `zone {zone.Id} references unknown monster {name}`)
		end
		for rarity in zone.EggWeights do
			t.truthy(Config.Eggs[rarity], `zone {zone.Id} references unknown egg {rarity}`)
		end
	end
	for rarity, egg in Config.Eggs do
		for petId in egg.PetWeights do
			t.truthy(Config.Pets[petId], `egg {rarity} references unknown pet {petId}`)
		end
	end
	for petId, pet in Config.Pets do
		t.eq(pet.Id, petId, "pet Id matches its key")
		t.truthy(Config.Evolution.FeedCostBase[pet.Rarity], `no feed cost for rarity {pet.Rarity}`)
	end
end)

t.test("shop has 5 weapons and 3 armor pieces with a free starter weapon", function()
	t.eq(#Config.Weapons, 5)
	t.eq(#Config.Armor, 3)
	t.eq(Config.Weapons[1].Price, 0)
	local ids = {}
	for _, item in Config.Weapons do
		t.truthy(not ids[item.Id], "duplicate id " .. item.Id)
		ids[item.Id] = true
	end
	for _, item in Config.Armor do
		t.truthy(not ids[item.Id], "duplicate id " .. item.Id)
		ids[item.Id] = true
	end
end)

t.test("every lockable plot slot has a price", function()
	for slot = Config.Plots.StartingSlots + 1, Config.Plots.MaxSlots do
		t.truthy(Config.Plots.SlotPrices[slot], `slot {slot} has no price`)
	end
end)

print("Weighted")

t.test("pick is deterministic and respects weights", function()
	local weights = { A = 1, B = 3 }
	t.eq(
		Weighted.pick(weights, function()
			return 0
		end),
		"A"
	)
	t.eq(
		Weighted.pick(weights, function()
			return 0.24
		end),
		"A"
	)
	t.eq(
		Weighted.pick(weights, function()
			return 0.26
		end),
		"B"
	)
	t.eq(
		Weighted.pick(weights, function()
			return 0.9999
		end),
		"B"
	)
	t.eq(Weighted.pick({}, math.random), nil)
end)

print("Leveling")

t.test("xp levels the player up and carries over the remainder", function()
	local data = fresh()
	local needed = Leveling.xpToNext(1)
	local gained = Leveling.addXp(data, needed + 5)
	t.eq(gained, 1)
	t.eq(data.Level, 2)
	t.eq(data.XP, 5)
end)

t.test("a big xp gain can grant several levels and stops at max level", function()
	local data = fresh()
	Leveling.addXp(data, 10 ^ 9)
	t.eq(data.Level, Config.Leveling.MaxLevel)
	t.eq(data.XP, 0)
end)

t.test("max health grows with level and armor", function()
	local data = fresh()
	local base = Leveling.maxHealth(data)
	t.eq(base, Config.Leveling.BaseHealth)
	data.Level = 3
	data.OwnedArmor.LeatherArmor = true
	data.EquippedArmor = "LeatherArmor"
	t.eq(Leveling.maxHealth(data), base + 2 * Config.Leveling.HealthPerLevel + Config.Armor[1].HealthBonus)
end)

print("Gear")

t.test("buying checks level and coins, deducts the price and equips", function()
	local data = fresh()
	local ok, msg = Gear.buy(data, "Weapon", "StoneSword")
	t.eq(ok, false)
	t.eq(msg, "Requires level 2")
	data.Level = 2
	ok = Gear.buy(data, "Weapon", "StoneSword")
	t.eq(ok, false, "should fail without coins")
	data.Coins = 1000
	ok = Gear.buy(data, "Weapon", "StoneSword")
	t.eq(ok, true)
	t.eq(data.Coins, 850)
	t.eq(data.EquippedWeapon, "StoneSword")
	ok = Gear.buy(data, "Weapon", "StoneSword")
	t.eq(ok, false, "cannot buy twice")
	ok = Gear.equip(data, "Weapon", "WoodenSword")
	t.eq(ok, true)
	t.eq(data.EquippedWeapon, "WoodenSword")
	ok = Gear.equip(data, "Armor", "PlateArmor")
	t.eq(ok, false, "cannot equip unowned armor")
	ok = Gear.buy(data, "Weapon", "Nope")
	t.eq(ok, false)
end)

print("Plot")

t.test("planting uses an egg and an unlocked empty slot", function()
	local data = fresh()
	t.eq(Plot.plant(data, 1, "Common", 1000), false, "no eggs yet")
	Plot.addEgg(data, "Common")
	Plot.addEgg(data, "Common")
	t.eq(Plot.plant(data, Config.Plots.StartingSlots + 1, "Common", 1000), false, "locked slot")
	t.eq(Plot.plant(data, 1, "Common", 1000), true)
	t.eq(data.Eggs.Common, 1)
	t.eq(Plot.plant(data, 1, "Common", 1000), false, "slot in use")
end)

t.test("growth uses saved timestamps so offline time counts", function()
	local data = fresh()
	Plot.addEgg(data, "Rare")
	Plot.plant(data, 2, "Rare", 1000)
	local slot = data.Plot["2"]
	local grow = Config.Eggs.Rare.GrowTime
	t.eq(Plot.progress(slot, 1000), 0)
	t.eq(Plot.progress(slot, 1000 + grow / 2), 0.5)
	t.eq(Plot.isReady(slot, 1000 + grow - 1), false)
	-- Simulates the player logging out and coming back much later.
	t.eq(Plot.isReady(slot, 1000 + grow * 10), true)
	t.eq(Plot.progress(slot, 1000 + grow * 10), 1)
end)

t.test("hatching waits for the timer and rolls from the egg's pet weights", function()
	local data = fresh()
	Plot.addEgg(data, "Legendary")
	Plot.plant(data, 1, "Legendary", 0)
	local ok = Plot.hatch(data, 1, 10, math.random)
	t.eq(ok, false, "not ready yet")
	local uid, petId
	ok, _, uid, petId = Plot.hatch(data, 1, Config.Eggs.Legendary.GrowTime, t.sequence({ 0.99 }))
	t.eq(ok, true)
	t.eq(petId, "Unicorn", "keys sort Dragon < Unicorn, so a high roll picks Unicorn")
	t.eq(data.Pets[uid].Id, "Unicorn")
	t.eq(data.Pets[uid].Stage, 1)
	t.eq(data.Plot["1"], nil, "slot is freed")
	t.eq(data.Stats.EggsHatched, 1)
end)

t.test("buying slots charges the configured price until the max", function()
	local data = fresh()
	data.Coins = 10 ^ 7
	local before = data.Coins
	t.eq(Plot.buySlot(data), true)
	t.eq(data.UnlockedSlots, Config.Plots.StartingSlots + 1)
	t.eq(data.Coins, before - Config.Plots.SlotPrices[Config.Plots.StartingSlots + 1])
	while data.UnlockedSlots < Config.Plots.MaxSlots do
		Plot.buySlot(data)
	end
	t.eq(Plot.buySlot(data), false)
end)

t.test("bestEgg prefers the rarest egg", function()
	local data = fresh()
	Plot.addEgg(data, "Common")
	Plot.addEgg(data, "Epic")
	Plot.addEgg(data, "Rare")
	t.eq(Plot.bestEgg(data), "Epic")
end)

print("Pets")

t.test("equip limit and multipliers", function()
	local data = fresh()
	local puppy = Pets.add(data, "Puppy")
	local kitty = Pets.add(data, "Kitty")
	local fox = Pets.add(data, "Fox")
	local wolf = Pets.add(data, "Wolf")
	t.eq(Pets.equip(data, puppy), true)
	t.eq(Pets.equip(data, puppy), false, "no double equip")
	t.eq(Pets.equip(data, kitty), true)
	t.eq(Pets.equip(data, fox), true)
	t.eq(Pets.equip(data, wolf), false, "max equipped")
	local m = Pets.getMultipliers(data)
	t.eq(m.Damage, 1 + Config.Pets.Puppy.Boost + Config.Pets.Fox.Boost)
	t.eq(m.Coins, 1 + Config.Pets.Kitty.Boost)
	t.eq(Pets.unequip(data, fox), true)
	t.eq(Pets.getMultipliers(data).Damage, 1 + Config.Pets.Puppy.Boost)
end)

t.test("merging 3 identical pets makes one pet a stage higher", function()
	local data = fresh()
	local a = Pets.add(data, "Puppy")
	local b = Pets.add(data, "Puppy")
	Pets.add(data, "Kitty")
	t.eq(Pets.merge(data, a), false, "only 2 puppies")
	local c = Pets.add(data, "Puppy")
	local d = Pets.add(data, "Puppy")
	Pets.equip(data, a)
	Pets.equip(data, d)
	local ok, _, newUid = Pets.merge(data, a)
	t.eq(ok, true)
	t.eq(data.Pets[a], nil)
	t.eq(data.Pets[b], nil, "unequipped duplicates are consumed first")
	t.eq(data.Pets[c], nil)
	t.truthy(data.Pets[d], "the equipped spare survives")
	t.eq(data.Pets[newUid].Stage, 2)
	t.truthy(Pets.isEquipped(data, newUid), "result inherits equipped state")
	t.eq(Pets.count(data), 3)
	t.eq(
		Pets.getMultipliers(data).Damage,
		1 + Config.Pets.Puppy.Boost * Config.Evolution.StageMultipliers[2] + Config.Pets.Puppy.Boost
	)
end)

t.test("feeding coins evolves a pet up to the max stage", function()
	local data = fresh()
	local uid = Pets.add(data, "Fox")
	local cost = Pets.feedCost(data.Pets[uid])
	t.eq(cost, Config.Evolution.FeedCostBase.Rare)
	t.eq(Pets.feed(data, uid), false, "no coins")
	data.Coins = 10 ^ 7
	t.eq(Pets.feed(data, uid), true)
	t.eq(data.Pets[uid].Stage, 2)
	t.eq(data.Coins, 10 ^ 7 - cost)
	for _ = 1, 10 do
		Pets.feed(data, uid)
	end
	t.eq(data.Pets[uid].Stage, Config.Evolution.MaxStage)
	t.eq(Pets.feedCost(data.Pets[uid]), nil)
	t.eq(Pets.feed(data, uid), false)
end)

t.test("sanitize drops equipped ids that no longer exist", function()
	local data = fresh()
	local uid = Pets.add(data, "Puppy")
	data.EquippedPets = { uid, "999", uid }
	Pets.sanitize(data)
	t.eq(#data.EquippedPets, 1)
	t.eq(data.EquippedPets[1], uid)
end)

print("Rewards")

t.test("kills give coins boosted by pets, xp, and egg drops", function()
	local data = fresh()
	local zone = Config.Zones[1]
	-- First roll decides the drop (0 < EggChance), second roll picks the rarity.
	local result = Rewards.applyKill(data, "Slime", zone, t.sequence({ 0, 0 }))
	t.eq(result.Coins, Config.Monsters.Slime.Coins)
	t.eq(data.Coins, Config.Monsters.Slime.Coins)
	t.eq(data.XP, Config.Monsters.Slime.XP)
	t.eq(result.Egg, "Common")
	t.eq(data.Eggs.Common, 1)
	t.eq(data.Stats.Kills, 1)

	local kitty = Pets.add(data, "Kitty")
	Pets.equip(data, kitty)
	result = Rewards.applyKill(data, "Goblin", zone, t.sequence({ 0.999 }))
	t.eq(result.Egg, nil, "high roll means no egg")
	t.eq(result.Coins, math.floor(Config.Monsters.Goblin.Coins * (1 + Config.Pets.Kitty.Boost) + 0.5))
end)

if not t.finish() then
	process.exit(1)
end
