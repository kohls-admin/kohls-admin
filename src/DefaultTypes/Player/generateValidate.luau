local function generateValidate(validate)
	return function(v, self)
		local ok, feedback = validate(v, self)
		return ok, feedback or "Invalid player"
	end
end

return generateValidate
