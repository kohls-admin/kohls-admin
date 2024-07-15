-- Prevents the loading of duplicates
if shared._K_LOADER then
	return
end
shared._K_LOADER = script.Parent

require(script.MainModule)
