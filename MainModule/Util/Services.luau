local Services = setmetatable({}, {
	__index = function(self, key: string)
		local service = game:GetService(key)
		self[key] = service
		return service
	end,
})

return Services
