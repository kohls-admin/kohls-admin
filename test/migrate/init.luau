local MainModule
if shared._K_LOADER_LOADED and not _G.KAU then
	MainModule = script:WaitForChild("KA")
else
	MainModule = script:WaitForChild("KAI")
end

script:WaitForChild("Tools").Parent = MainModule

require(MainModule)
