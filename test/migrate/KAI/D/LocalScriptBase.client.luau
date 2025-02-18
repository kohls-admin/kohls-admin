local codeInstance = script:WaitForChild("Code")
local code = codeInstance.Value
codeInstance:Destroy()

local parse = script:WaitForChild("Loadstring")
local execute = require(parse)
parse:Destroy()
execute(code, getfenv())()
