if shared._K_LOADER_LOADED and not _G.KAU then
	return require(script:WaitForChild("KA"))
else
	return require(script:WaitForChild("KAI"))
end
