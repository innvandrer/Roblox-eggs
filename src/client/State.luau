--!strict
-- Latest state snapshot pushed by the server (see DataService.snapshot).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Logic.Types)
local Net = require(script.Parent.Net)

export type Snapshot = {
	Data: Types.PlayerData,
	XpToNext: number,
	MaxHealth: number,
	Multipliers: Types.Multipliers,
	NextSlotPrice: number?,
	ServerTime: number,
}

local State = {}

State.current = nil :: Snapshot?

local listeners: { (Snapshot) -> () } = {}

function State.onChanged(listener: (Snapshot) -> ())
	table.insert(listeners, listener)
	if State.current then
		task.spawn(listener, State.current)
	end
end

-- Unix time matching the server's os.time(), used for growth timers.
function State.now(): number
	return workspace:GetServerTimeNow()
end

Net.State:Observe(function(snapshot: Snapshot?)
	if snapshot == nil then
		return
	end
	State.current = snapshot
	for _, listener in listeners do
		task.spawn(listener, snapshot)
	end
end)

return State
