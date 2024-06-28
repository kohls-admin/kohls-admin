local Signal = require(script.Parent.Parent.Parent.Util.SignalGood)

local function Lock(obj) -- returns read only proxy for table
	if type(obj) == "table" then
		local name = obj.ClassName or getfenv(2).script.Name
		local new = newproxy(true)
		local mt = getmetatable(new)

		mt.__index = obj
		mt.__metatable = ("[%s] metatable is locked."):format(name)
		function mt:__newindex(k, v)
			warn("Cannot write to read-only table!")
		end
		function mt:__tostring()
			return name
		end

		return new
	end
end

local function Sift(t)
	for x = 1, #t do
		t[t[x]] = false
		t[x] = nil
	end
end

local Classes = {}
local metaTables = setmetatable({}, { __mode = "kv" })
local objTables = setmetatable({}, { __mode = "kv" })

local Class = {
	Classes = Classes,
	metaTables = metaTables,
	objTables = objTables,
	Signal = Signal,
	CheckType = function(val, ...)
		val = typeof(val)
		local t = { ... }
		for x = 1, #t do
			if val == t[x] then
				return
			end
		end
		error(string.format("Invalid type: <%s> expected, got <%s>", table.concat(t, " / "), val), 2)
	end,
}

local dataKeys = { "_event", "_hide", "_func", "_prop", "_wrap" }

function Class:Create(data)
	local name = data._name
	Class.CheckType(name, "string")

	if Classes[name] then
		warn(name, " class cannot be created, already exists.")
		return Classes[name]
	end

	for x = 1, #dataKeys do
		local v = dataKeys[x]
		if not data[v] then
			data[v] = {}
		end
	end

	Sift(data._event)
	Sift(data._hide)

	data._super = data._super or name ~= "BaseClass" and "BaseClass"
	local super = Classes[data._super]

	if not super then
		super = script:FindFirstChild(data._super)
		if super then
			super = require(super)
		end
	end

	if super then
		data._super = super
		for x = 1, #dataKeys do
			local key = dataKeys[x]
			local tab = data[key]
			for k, v in next, super[key] do
				if not tab[k] then
					tab[k] = v
				end
			end
		end
	end

	data.ClassName = name

	local locked = Lock(data)
	Classes[name] = locked
	Classes[locked] = locked
	return locked
end

local defaultMeta = {
	__index = function(this, k)
		local self = metaTables[this] or this -- internal copy
		local class = self._class
		local v = self._data[k] or class._func[k]

		if v == nil then
			local ref = class._prop[k]
			if typeof(ref) == "Instance" then
				return ref[k]
			end
		end

		if v == nil and not class._prop[k] then
			local event = class._event[k]
			if event ~= nil then
				if self == this then -- if internal access
					local signal = Signal.new()
					if type(event) == "function" then
						event(self, signal)
					end
					rawset(self, k, signal)
					return signal
				else
					return self[k]
				end
			end
		end

		if v == nil and self._data._rbx then
			local bool, v = pcall(function()
				return self._data._rbx[k]
			end)
			if bool then
				return type(v) == "function" and function(_, ...)
					v(self._data._rbx, ...)
				end or v
			end
		end

		return v
	end,

	__newindex = function(this, k, v)
		local self = metaTables[this] or this
		local prop = self._class._prop[k]
		local propType = typeof(prop)

		if propType == "function" then
			prop(self, v)
		--		elseif propType == 'Instance' then
		--			prop[k] = v
		elseif self == this and self._class._hide[k] ~= nil then
			rawset(self, k, v)
		elseif self._rbx then
			local bool, res = pcall(function()
				return self._rbx[k]
			end)
			if bool and type(res) ~= "function" and typeof(res) ~= "RBXScriptSignal" then
				self._rbx[k] = v
			end
		else
			warn(k .. " is not a modifiable property!")
		end
	end,

	__tostring = function(self)
		return (metaTables[self] or self)._class.ClassName
	end,
}

function Class.new(className, obj)
	local class = Classes[className]
	if not class then
		class = script:FindFirstChild(className)
		if class then
			class = require(class)
		end
	end

	if class then
		local self = newproxy(true)
		local mt = getmetatable(self)

		for k, v in next, class._hide do
			mt[k] = v
		end
		for k, v in next, defaultMeta do
			mt[k] = v
		end

		mt._data = {}
		mt._class = class

		metaTables[self] = setmetatable(mt, mt)
		metaTables[mt] = metaTables[self]

		local inits, x = {}, class
		while x do
			table.insert(inits, 1, x)
			x = x._super
		end
		for x = 1, #inits do
			local v = inits[x]
			if v._init then
				v._init(mt, obj)
			end
		end

		if self._rbx then
			objTables[self._rbx] = self
		end

		return self
	end
end

return Lock(Class)
