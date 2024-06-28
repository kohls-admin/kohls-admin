local function Copy(obj, seen)
	if type(obj) ~= "table" then
		return obj
	end
	if seen and seen[obj] then
		return seen[obj]
	end
	local copy = setmetatable({}, getmetatable(obj))
	seen = seen or {}
	seen[obj] = copy
	for k, v in next, obj do
		copy[Copy(k, seen)] = Copy(v, seen)
	end
	return copy
end

local Class = require(script.Parent)

return Class:Create({
	_name = "BaseClass",

	_event = { "Changed" },

	_hide = {
		"Children",
		"Signals",
		"ThemeData",

		rawset = function(self, k, v)
			self._data[k] = v

			if self._class._prop[k] then
				self.Changed:Fire(k)
			end

			local signal = self.Signals and self.Signals[k]
			if signal then
				signal:Fire(v)
			end

			return self
		end,
	},

	_func = {
		Clone = function(self) -- may not work properly
			if self.Archivable then
				local class = self._class or Class.metaTables[self]._class
				local new = Class.new(class._name)
				repeat
					for k in next, class._prop do
						if k ~= "parent" then
							local old = self[k]
							if old ~= nil then
								if typeof(old) == "Instance" or Class.metaTables[old] then
									old = old:Clone()
								end
								new[k] = old
							end
						end
					end
					class = class._super
				until not class
				return new
			end
			return nil
		end,

		GetFullName = function(self)
			return self.Parent and (self.Parent:GetFullName() .. "." .. self.Name) or self.Name
		end,

		IsDescendantOf = function(self, ancestor)
			return self.Parent and (self.Parent == ancestor or self.Parent:IsDescendantOf(ancestor))
		end,

		GetPropertyChangedSignal = function(self, k)
			if type(k) ~= "string" then
				return warn("Invalid argument: <string> expected, got", k)
			end

			local signal = self.Signals[k]
			if not signal then
				if not self._class._prop[k] then
					return warn(k, "is not a valid property of", self.Name)
				end
				signal = Class.Signal.new()
				self.Signals[k] = signal
			end

			return signal
		end,

		FindFirstChild = function(self, name, recursive)
			local children = self.Children
			for i = 1, #children do
				local v = children[i]
				return v.Name == name and v or recursive and v:FindFirstChild(name, recursive)
			end
		end,

		GetChildren = function(self)
			return Copy(self.Children)
		end,

		IsA = function(self, className)
			local class = self._class
			repeat
				if className == class.ClassName then
					return true
				end
				class = class._super
			until not class
			return false
		end,

		Destroy = function(self)
			self.Archivable = false
			self.Parent = nil

			if self._rbx then
				self._rbx:Destroy()
			end

			if self._data then
				for k in next, self._data do
					rawset(self._data, k, nil)
				end
			end

			if self.Signals then
				for k, v in next, self.Signals do
					if v:IsA("BindableEvent") then
						v:Destroy()
					end
					rawset(self, k, nil)
				end
			end

			for k, v in next, self do
				if v:IsA("BindableEvent") then
					v:Destroy()
				end
				rawset(self, k, nil)
			end
		end,
	},

	_prop = {
		Archivable = function(self, v)
			Class.CheckType(v, "boolean")
			self:rawset("Archivable", v)
			if self._rbx then
				self._rbx.Archivable = v
			end
		end,

		Name = function(self, v)
			self:rawset("Name", tostring(v))
			if self._rbx then
				self._rbx.Name = tostring(v)
			end
		end,

		Parent = function(self, v)
			if typeof(v) ~= "Instance" and Class.metaTables[v] == nil and v ~= nil then
				return warn("Invalid argument: <Instance> expected, got", typeof(v))
			end
			local oldParent = Class.metaTables[self.Parent]
			if oldParent then
				local list = oldParent.Children
				if list then
					for i, child in next, list do
						if child == self then
							table.remove(list, i)
						end
					end
				end
			end
			self:rawset("Parent", v)
			if typeof(v) == "Instance" and self._rbx then
				self._rbx.Parent = v
			else
				v = Class.metaTables[v]
				if v then
					table.insert(v.Children, self)
					if self._rbx then
						if v._parentTo then
							self._rbx.Parent = v._parentTo
						elseif v._rbx then
							self._rbx.Parent = v._rbx
						end
					end
				end
			end
			if self.ParentUpdate then
				self.ParentUpdate(self, v)
			end
		end,

		Theme = function(self, theme)
			if type(theme) == "table" and theme ~= self.Theme then
				local old = self.Theme
				self:rawset("Theme", theme)
				if self._rbx then
					if old then
						old:Strip(self._rbx)
					end
					for obj, dat in next, self.ThemeData do
						for k, v in next, dat do
							if type(v) == "table" then
								v[1] = theme[v[1]]
							else
								v = theme[v]
							end
							theme.Add(obj, k, v)
						end
					end
				end
			end
		end,
	},

	_init = function(self)
		local name = self._class.ClassName
		self:rawset("ClassName", name) -- read-only

		self.Archivable = true
		self.Name = name

		self.Children = {}
		self.Signals = {}
		self.ThemeData = {}
	end,
})
