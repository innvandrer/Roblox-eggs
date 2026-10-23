--!strict
-- Server-side backup for zone level requirements: anyone inside a zone they are too low level for
-- gets sent back to spawn. (Clients also make the zone walls solid locally.)

local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)

local CHECK_INTERVAL = 0.5

local ZoneService = {}

function ZoneService.init()
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if data and root and root:IsA("BasePart") then
					local zone = MapService.zoneAt(root.Position)
					if zone and data.Level < zone.LevelRequired then
						root.CFrame = CFrame.new(MapService.SpawnPosition)
						DataService.notify(player, `{zone.Name} unlocks at level {zone.LevelRequired}`, "error")
					end
				end
			end
		end
	end)
end

return ZoneService
