--!strict
-- Binds client-callable actions. Every handler receives the caller's loaded data and returns
-- (ok, message). Successful actions push a fresh state snapshot; messages are shown as toasts.

local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local Types = require(game:GetService("ReplicatedStorage").Shared.Logic.Types)

local MIN_INTERVAL = 0.15

local Actions = {}

local lastCall: { [Player]: { [string]: number } } = {}

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastCall[player] = nil
end)

function Actions.bind(name: string, handler: (player: Player, data: Types.PlayerData, ...any) -> (boolean, string?))
	Net.comm:BindFunction(name, function(player: Player, ...: any): (boolean, string?)
		local now = os.clock()
		local calls = lastCall[player] or {}
		lastCall[player] = calls
		if calls[name] and now - calls[name] < MIN_INTERVAL then
			return false, "Slow down"
		end
		calls[name] = now

		local data = DataService.get(player)
		if not data then
			return false, "Your data is still loading"
		end
		local success, ok, message = pcall(handler, player, data, ...)
		if not success then
			warn(`Action {name} failed for {player.Name}: {ok}`)
			return false, "Something went wrong"
		end
		if ok then
			DataService.changed(player)
		end
		if type(message) == "string" then
			DataService.notify(player, message, if ok then "success" else "error")
		end
		return ok, message
	end)
end

return Actions
