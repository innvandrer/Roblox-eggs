--!strict
-- Loads and saves player data with ProfileStore and pushes state snapshots to clients.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore) :: any

local Config = require(ReplicatedStorage.Shared.Config)
local DataTemplate = require(ReplicatedStorage.Shared.Logic.DataTemplate)
local Leveling = require(ReplicatedStorage.Shared.Logic.Leveling)
local Pets = require(ReplicatedStorage.Shared.Logic.Pets)
local Plot = require(ReplicatedStorage.Shared.Logic.Plot)
local Types = require(ReplicatedStorage.Shared.Logic.Types)
local Net = require(script.Parent.Net)

-- Bump the store name to wipe all saves during development.
local STORE_NAME = "PlayerData_v1"

local DataService = {}

type LoadedCallback = (player: Player, data: Types.PlayerData) -> ()

local store = ProfileStore.New(STORE_NAME, DataTemplate.create())
local profiles: { [Player]: any } = {}
local loadedCallbacks: { LoadedCallback } = {}
local pendingPush: { [Player]: boolean } = {}

function DataService.get(player: Player): Types.PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- Runs `callback` for every player whose data is loaded, now and in the future.
function DataService.onLoaded(callback: LoadedCallback)
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
end

function DataService.snapshot(data: Types.PlayerData)
	return {
		Data = data,
		XpToNext = Leveling.xpToNext(data.Level),
		MaxHealth = Leveling.maxHealth(data),
		Multipliers = Pets.getMultipliers(data),
		NextSlotPrice = Plot.nextSlotPrice(data),
		ServerTime = os.time(),
	}
end

local function updateLeaderstats(player: Player, data: Types.PlayerData)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local coins = leaderstats:FindFirstChild("Coins")
	local level = leaderstats:FindFirstChild("Level")
	if coins and coins:IsA("IntValue") then
		coins.Value = data.Coins
	end
	if level and level:IsA("IntValue") then
		level.Value = data.Level
	end
end

local function push(player: Player)
	local data = DataService.get(player)
	if not data or player.Parent ~= Players then
		return
	end
	updateLeaderstats(player, data)
	Net.State:SetFor(player, DataService.snapshot(data))
end

-- Call after mutating a player's data. Multiple calls in the same frame are batched into one push.
function DataService.changed(player: Player)
	if pendingPush[player] then
		return
	end
	pendingPush[player] = true
	task.defer(function()
		pendingPush[player] = nil
		push(player)
	end)
end

function DataService.notify(player: Player, text: string, kind: string?)
	Net.Notify:Fire(player, text, kind or "info")
end

local function migrate(data: Types.PlayerData)
	if not data.OwnedWeapons[data.EquippedWeapon] then
		data.EquippedWeapon = Config.Weapons[1].Id
		data.OwnedWeapons[data.EquippedWeapon] = true
	end
	if data.EquippedArmor ~= "" and not data.OwnedArmor[data.EquippedArmor] then
		data.EquippedArmor = ""
	end
	data.UnlockedSlots = math.clamp(data.UnlockedSlots, Config.Plots.StartingSlots, Config.Plots.MaxSlots)
	Pets.sanitize(data)
end

local function createLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = leaderstats
	leaderstats.Parent = player
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Your data could not be loaded. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data was loaded on another server. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	migrate(profile.Data)
	profiles[player] = profile
	createLeaderstats(player)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile.Data)
	end
	push(player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	if profile then
		profile:EndSession()
	end
end

function DataService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return DataService
