-- Prevents the loading of duplicates
if shared._K_LOADER then
	script.Parent:Destroy()
else
	shared._K_LOADER = script.Parent
	local settings = require(script.Parent.Settings)
	--force the demo place to not auto update
	if false and settings.autoUpdate and game.PlaceId ~= 18274376677 then
	else
		require(script.MainModule)
	end
end
