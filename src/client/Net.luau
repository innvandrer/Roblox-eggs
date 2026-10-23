--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Comm = require(ReplicatedStorage.Packages.Comm)

local comm = Comm.ClientComm.new(ReplicatedStorage, false, "Net")

local Net = {
	State = comm:GetProperty("State"),
	Notify = comm:GetSignal("Notify"),
	Effect = comm:GetSignal("Effect"),
}

local functions: { [string]: (...any) -> ...any } = {}

-- Invokes a server action. The server shows any result message as a toast itself.
function Net.call(name: string, ...: any): (boolean, string?)
	local fn = functions[name]
	if not fn then
		fn = comm:GetFunction(name)
		functions[name] = fn
	end
	local ok, result, message = pcall(fn, ...)
	if not ok then
		warn(`Call {name} failed: {result}`)
		return false, nil
	end
	return result == true, message
end

-- Fire-and-forget version for button handlers.
function Net.send(name: string, ...: any)
	task.spawn(Net.call, name, ...)
end

return Net
