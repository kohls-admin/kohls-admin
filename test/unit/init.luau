--!strict
local sert = require("./sert")
assert(type(sert.loaded) == "function", "sert.loaded must be a function")

sert.loaded(require("./unit/Util.spec"))
sert.loaded(require("./unit/ProcessAndTypes.spec"))
sert.loaded(require("./unit/Auth.spec"))
sert.loaded(require("./unit/DataAndSim.spec"))
sert.loaded(require("./unit/Remote.spec"))
sert.loaded(require("./unit/ChatAndServer.spec"))
sert.loaded(require("./unit/DefaultTypes.spec"))
sert.loaded(require("./unit/DefaultCommands.spec"))
sert.loaded(require("./unit/ClientAndUI.spec"))
sert.loaded(require("./unit/Loadstring.spec"))
sert.loaded(require("./unit/Studio.spec"))

return {}
