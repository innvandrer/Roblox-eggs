-- Loads Roblox-style ModuleScripts from disk under Lune.
-- Emulates `script`, `script.Parent.Child` and `require(<script ref>)`, and exposes Roblox datatypes
-- (Color3, Vector3, ...) as globals, so pure shared modules can run headlessly.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any

local harness = {}

local cache: { [string]: any } = {}
local baseEnv = getfenv()

local makeRef: (path: string) -> any
local requireRef: (ref: any) -> any

local function parentDir(path: string): string
	return string.match(path, "^(.*)/[^/]+$") or "."
end

local function resolveFile(path: string): string?
	if fs.isFile(path .. ".luau") then
		return path .. ".luau"
	elseif fs.isFile(path .. ".lua") then
		return path .. ".lua"
	elseif fs.isDir(path) and fs.isFile(path .. "/init.luau") then
		return path .. "/init.luau"
	end
	return nil
end

-- A ref is a stand-in for an Instance at `path` (a file path without extension, or a directory).
function makeRef(path: string): any
	return setmetatable({ __path = path }, {
		__index = function(_self, key)
			if key == "Parent" then
				return makeRef(parentDir(path))
			elseif key == "Name" then
				return string.match(path, "([^/]+)$")
			end
			return makeRef(path .. "/" .. key)
		end,
		__tostring = function()
			return "Ref(" .. path .. ")"
		end,
	})
end

local function loadFile(file: string): any
	if cache[file] ~= nil then
		return cache[file]
	end
	local scriptPath = string.gsub(file, "%.luau?$", "")
	scriptPath = string.gsub(scriptPath, "/init$", "")
	local env = setmetatable({
		script = makeRef(scriptPath),
		require = requireRef,
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
		UDim2 = roblox.UDim2,
	}, { __index = baseEnv })
	local chunk = luau.load(fs.readFile(file), { debugName = file, environment = env })
	local result = chunk()
	cache[file] = result
	return result
end

function requireRef(ref: any): any
	if type(ref) == "string" then
		return require(ref)
	end
	local path = rawget(ref, "__path")
	assert(path, "require() expects a script reference")
	local file = resolveFile(path)
	assert(file, "Module not found: " .. path)
	return loadFile(file)
end

-- Requires a module by repo-relative path, e.g. harness.require("src/shared/Logic/Pets").
function harness.require(path: string): any
	return requireRef(makeRef(path))
end

-- Deterministic rng that returns the given values in order (then repeats the last one).
function harness.sequence(values: { number }): () -> number
	local i = 0
	return function()
		i = math.min(i + 1, #values)
		return values[i]
	end
end

local passed, failed = 0, 0

function harness.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end

function harness.eq(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(`{message or "values differ"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function harness.truthy(value: any, message: string?)
	if not value then
		error(message or "expected a truthy value", 2)
	end
end

function harness.finish(): boolean
	print(`\n{passed} passed, {failed} failed`)
	return failed == 0
end

return harness
