--!strict
-- Remote endpoints shared by all server services. The client mirrors these in src/client/Net.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Comm = require(ReplicatedStorage.Packages.Comm)

local comm = Comm.ServerComm.new(ReplicatedStorage, "Net")

return {
	comm = comm,
	-- Per-player snapshot of saved data plus derived values (see DataService.snapshot).
	State = comm:CreateProperty("State", nil),
	-- (text: string, kind: "info" | "success" | "error" | "reward")
	Notify = comm:CreateSignal("Notify"),
	-- (kind: string, ...) one-off visual effects such as damage popups and egg drops.
	Effect = comm:CreateSignal("Effect"),
	-- Client -> server: the player swung their weapon. Hit detection happens on the server.
	Attack = comm:CreateSignal("Attack"),
}
