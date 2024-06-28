-- Prevents the loading of duplicates
if shared._K_LOADER then
	return
end
shared._K_LOADER = script.Parent

-- require included modulescript or id based on settings

require(script.MainModule)
