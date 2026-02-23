local Property = {}

-- originalValue, overrideValue, propertyChangedConnection, internalChange
local overrideCache = {}
Property.cache = overrideCache

function Property.override(instance: Instance, property: string, value: any)
	local overrides = overrideCache[instance]
	if not overrides then
		overrides = {}
		overrideCache[instance] = overrides
		instance.Destroying:Once(function()
			for property in overrides do
				Property.reset(instance, property)
			end
			table.clear(overrides)
			overrideCache[instance] = nil
		end)
	end

	local cache = overrides[property]
	if not cache then
		cache = { instance[property] }
		overrides[property] = cache
		cache[3] = instance:GetPropertyChangedSignal(property):Connect(function()
			if not cache or cache[4] then
				return -- override change
			end
			-- update cache with external change
			cache[1] = instance[property]
			-- re-apply override value
			cache[4] = true
			instance[property] = cache[2]
			cache[4] = false
		end)
	end

	-- cache overrideValue
	cache[2] = value

	-- apply override value
	cache[4] = true
	instance[property] = value
	cache[4] = false
end

function Property.reset(instance: Instance, property: string)
	local overrides = overrideCache[instance]
	local cache = if overrides then overrides[property] else nil

	if cache then
		if typeof(cache[3]) == "RBXScriptConnection" then
			cache[3]:Disconnect()
		end

		instance[property] = cache[1]
		overrides[property] = nil

		table.clear(cache)
	end
end

return Property
