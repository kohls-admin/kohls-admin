shared._K_DEBUG = true

repeat
	task.wait()
until shared._K_INTERFACE
local _K = shared._K_INTERFACE

table.insert(_K.Data.loaderSettings.freeAdmin, "admin")

return _K
