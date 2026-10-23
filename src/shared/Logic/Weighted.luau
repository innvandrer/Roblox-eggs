--!strict
local Types = require(script.Parent.Types)

-- Picks a key from a { [key] = weight } table. Keys are sorted first so a given rng value
-- always maps to the same result, which keeps rolls reproducible in tests.
local function pick(weights: { [string]: number }, rng: Types.Rng): string?
	local keys = {}
	local total = 0
	for key, weight in weights do
		if weight > 0 then
			table.insert(keys, key)
			total += weight
		end
	end
	if total <= 0 then
		return nil
	end
	table.sort(keys)

	local roll = rng() * total
	for _, key in keys do
		roll -= weights[key]
		if roll < 0 then
			return key
		end
	end
	return keys[#keys]
end

return {
	pick = pick,
}
