--!strict
-- Credited contributors and special thanks for the About page.
-- `active` sets the commit threshold and day window read by About/Order.luau and .github/scripts/credits.py.
export type Person = { Id: number, GitHub: string?, Tooltip: string? }
export type Credits = {
	active: { commits: number, days: number },
	people: { Person },
	specialThanks: Person,
}

local credits: Credits = {
	active = { commits = 2, days = 365 },
	people = {
		-- core & leads
		{ Id = 44391621, GitHub = "kohltastrophe", Tooltip = "Creator of Kohl's Admin." }, -- kohl
		{ Id = 15554260, GitHub = "zeejayym", Tooltip = "Web development and documentation." }, -- zeejaym
		{ Id = 3286467, Tooltip = "System design and planning." }, -- lejam7890
		{ Id = 521855368, Tooltip = "Strategy, design, and planning." }, -- rfov
		{ Id = 1022854840, Tooltip = "3D modeling and UGC design." }, -- JJJ
		{ Id = 15303771, Tooltip = "Design planning and quality assurance." }, -- Fragility
		{ Id = 131233603, GitHub = "GiddG", Tooltip = "Design, direction, and community lead." }, -- Geed

		-- code & docs contributors
		{ Id = 201989656, GitHub = "iirealisticdev", Tooltip = "Argument validation and addon examples." }, -- iiRealistic_Dev
		{ Id = 14658110, GitHub = "rietria", Tooltip = "Team respawn, substitute, noobify, and flight tweaks." }, -- Rietria
		{ Id = 448137594, GitHub = "Lucatacos", Tooltip = "Command aliases, settings, and Z Axes fixes." }, -- Lucatacos
		{ Id = 483215789, GitHub = "crazyrb", Tooltip = "Documentation guides." }, -- seil
		{ Id = 345072461, GitHub = "ryanlua", Tooltip = "Rokit toolchain, devcontainers, and CI." }, -- raenlua
		{ Id = 130170862, GitHub = "TheHackerLxr", Tooltip = "Security policy and fun commands." }, -- matsagor1
		{ Id = 444317184, GitHub = "vonials", Tooltip = "Documentation and legacy ban defaults." }, -- vonials
		{ Id = 41336494, GitHub = "calculatous", Tooltip = "Ban exemptions and command aliases." }, -- Calculatous
		{ Id = 35818691, GitHub = "lightofthestars", Tooltip = "Theme permissions, menu bounds, and log filters." }, -- greeny
		{ Id = 83478451, GitHub = "StevenDahFish", Tooltip = "Documentation navigation fixes." }, -- stevendahfish
		{ Id = 2014793803, GitHub = "LayzieBones", Tooltip = "Loopkill command." }, -- SkellyLua
		{ Id = 7034077053, GitHub = "wingstosky256", Tooltip = "About page initialization fix." }, -- johnny_klebitz1 (Wingstosky)
		{ Id = 190022817, Tooltip = "Headless, korblox, werewolf, and vampire commands." }, -- emblazes
		{ Id = 2536605621, GitHub = "ItzMrRatsP", Tooltip = "Flux reactive tags, bindings, and ColorSequence motion." }, -- ItzMrRatsP
		{ Id = 352492, GitHub = "DylWithlt", Tooltip = "Flux Edit edge cases and owner error diagnostics." }, -- DylWithlt
		{ Id = 558808710, GitHub = "XoifaiI", Tooltip = "Flux state fast paths and observer cleanup." }, -- XoifaiI
		{ Id = 958742555, GitHub = "neopolitans", Tooltip = "Goldify and silverify commands, and Z TriangleMesh." }, -- neopolitans
		{ Id = 1025103658, GitHub = "meisox", Tooltip = "JumpPower handling and Flux forValue nil checks." }, -- Mei
		{ Id = 3727541395, GitHub = "luv2trilogy", Tooltip = "Poll command, VIP hat cache fix, and Window cleanup." }, -- p3taliie

		-- community support & testing
		{ Id = 2773879457 }, -- therealfaylix
		{ Id = 1224156917 }, -- dalien
		{ Id = 195261420 }, -- exobyte
		{ Id = 208790398 }, -- chan
		{ Id = 3357116228 }, -- lemon
		{ Id = 1686847974 }, -- stone
		{ Id = 3470429081 }, -- Mercury
		{ Id = 1142396048 }, -- Franklin_Surten (H)
		{ Id = 77608258 }, -- icarus
		{ Id = 1219753275 }, -- DZIDZIO999
		{ Id = 127757866 }, -- iam_danny
		{ Id = 197640401 }, -- swibes
		{ Id = 75214485 }, -- ericance
		{ Id = 46236725 }, -- Doroku
		{ Id = 1560379748 }, -- mosha
		{ Id = 200565345 }, -- easternbloxxer
		{ Id = 107192912 }, -- britishtrainspotting
		{ Id = 2258246 }, -- emp
		{ Id = 129134882 }, -- horracecat
		{ Id = 146573772 }, -- metallochrome
		{ Id = 496062049 }, -- pachiswack
		{ Id = 1279022258 }, -- arcane
		{ Id = 2297254 }, -- min
		{ Id = 672360774 }, -- xaz
		{ Id = 9345226 }, -- tomspell
		{ Id = 3230955923 }, -- napiw
		{ Id = 516417505 }, -- landon
		{ Id = 105503420 }, -- general_legendary
		{ Id = 4847574 }, -- mets

		-- inspiration & ecosystem
		{ Id = 1237666, Tooltip = "Creator of Adonis and EISS." }, -- Sceleratis
		{ Id = 214258, Tooltip = "Creator of Person299's Admin Commands." }, -- Person299
		{ Id = 82347291, Tooltip = "Creator of TopbarPlus and HD Admin." }, -- ForeverHD
		{ Id = 576473, Tooltip = "Creator of Rojo." }, -- lpg
		{ Id = 92658764, Tooltip = "Creator of Moonwave and Cmdr." }, -- evaera
		{ Id = 484140, Tooltip = "Creator of Building Tools by F3X." }, -- GigsD4x
		{ Id = 2722909519, Tooltip = "Creator of Squash." }, -- sona
		{ Id = 4812582, Tooltip = "Designer of the Classic Sword." }, -- Sharksie
		{ Id = 648020, Tooltip = "Pioneered Roblox group development." }, -- trick555
		{ Id = 1670764, Tooltip = "Creator of Fusion." }, -- Elttob
		{ Id = 70540486, Tooltip = "Luau optimization and bytecode research." }, -- reru
	},
	specialThanks = {
		Id = 16, -- erik.cassel
		Tooltip = "For imagining the world we build in.",
	},
}

return credits
