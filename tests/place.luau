-- Checks the built place file has the expected structure.
-- Run with: lune run tests/place.luau [path/to/place.rbxlx]  (from the repo root, after `rojo build`)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox") :: any

local path = process.args[1] or "build/Roblox-eggs.rbxlx"
local game = roblox.deserializePlace(fs.readFile(path))

local failures = 0

local function find(pathParts: { string }): any
	local current = game
	for _, name in pathParts do
		current = current:FindFirstChild(name)
		if not current then
			return nil
		end
	end
	return current
end

local function expect(pathParts: { string }, className: string)
	local instance = find(pathParts)
	local label = table.concat(pathParts, ".")
	if not instance then
		failures += 1
		print("  FAIL missing " .. label)
	elseif instance.ClassName ~= className then
		failures += 1
		print(`  FAIL {label} is a {instance.ClassName}, expected {className}`)
	else
		print(`  ok   {label} ({className})`)
	end
end

expect({ "ServerScriptService", "Server", "Main" }, "Script")
for _, name in { "Actions", "CombatService", "DataService", "MapService", "MonsterService", "Net", "PetService" } do
	expect({ "ServerScriptService", "Server", "Services", name }, "ModuleScript")
end
for _, name in { "PlotService", "ShopService", "ZoneService" } do
	expect({ "ServerScriptService", "Server", "Services", name }, "ModuleScript")
end
expect({ "StarterPlayer", "StarterPlayerScripts", "Client", "Main" }, "LocalScript")
for _, name in
	{ "Combat", "Effects", "Hud", "Menus", "Net", "Notifications", "PetsMenu", "PlotMenu", "ShopMenu", "State" }
do
	expect({ "StarterPlayer", "StarterPlayerScripts", "Client", name }, "ModuleScript")
end
expect({ "ReplicatedStorage", "Shared", "Config" }, "ModuleScript")
expect({ "ReplicatedStorage", "Shared", "Config", "Weapons" }, "ModuleScript")
expect({ "ReplicatedStorage", "Shared", "Logic", "Pets" }, "ModuleScript")
expect({ "ReplicatedStorage", "Packages", "Comm" }, "ModuleScript")
expect({ "ServerStorage", "ServerPackages", "ProfileStore" }, "ModuleScript")

local workspace = game:GetService("Workspace")
if workspace.StreamingEnabled ~= false then
	failures += 1
	print("  FAIL Workspace.StreamingEnabled should be false")
end

print(if failures == 0 then "\nplace structure ok" else `\n{failures} problem(s)`)
if failures > 0 then
	process.exit(1)
end
