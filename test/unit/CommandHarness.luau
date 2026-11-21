--!nocheck
local Harness = require("./Harness")
local sert = require("../sert")

local _globals = Harness.globals
local CFrame = _globals.CFrame
local Vector3 = _globals.Vector3
local Enum = _globals.Enum

-- Rich character and service double builder for testing all DefaultCommands & VIP modules
local function decorateEnvironment(peerEnv: any)
	local origInstNew = peerEnv.Instance.new
	local customInstLib = table.freeze({
		new = function(className: string, parent: any?)
			local inst = origInstNew(className, parent)
			if className == "ViewportFrame" then
				inst._props.TouchPinch = peerEnv:signal()
			elseif className == "AudioTextToSpeech" then
				inst._props.Ended = peerEnv:signal()
				rawset(inst, "_methods", {
					LoadAsync = function(self: any)
						return self._props._loadStatus or Enum.AssetFetchStatus.Success
					end,
					Play = function(self: any)
						self._props._playing = true
					end,
					Unload = function(self: any)
						self._props._unloaded = true
					end,
				})
			end
			return inst
		end,
		fromExisting = peerEnv.Instance.fromExisting,
	})
	peerEnv.Instance = customInstLib
	rawset(peerEnv.globals, "Instance", customInstLib)

	-- Ensure Terrain has Clear
	local terrain = peerEnv.workspace.Terrain
	local terrainMethods = rawget(terrain, "_methods") or {}
	terrainMethods.Clear = function(self: any)
		self._props._cleared = true
	end
	rawset(terrain, "_methods", terrainMethods)

	-- Ensure Chat service has Chat method
	local chatService = peerEnv.game:GetService("Chat")
	local chatMethods = rawget(chatService, "_methods") or {}
	chatMethods.Chat = function(_self: any, partOrChar: any, message: string)
		chatService._props._lastChat = { target = partOrChar, message = message }
	end
	rawset(chatService, "_methods", chatMethods)

	-- Ensure GroupService has PromptJoinAsync, GetRolesInGroupAsync, and GetGroupInfoAsync
	local groupService = peerEnv.game:GetService("GroupService")
	local groupMethods = rawget(groupService, "_methods") or {}
	groupMethods.PromptJoinAsync = function(_self: any, groupId: number)
		groupService._props._lastPromptGroup = groupId
		return Enum.GroupMembershipStatus.Joined
	end
	groupMethods.GetRolesInGroupAsync = function(_self: any, userId: number, groupId: number?)
		local roles = {}
		local sourceGroups = if groupId then { [groupId] = peerEnv.groups[groupId] } else peerEnv.groups
		for gid, g in sourceGroups do
			local rank = g and g.ranks and g.ranks[userId]
			if rank then
				table.insert(roles, { Id = gid, Name = g.Name or `Group{gid}`, Rank = rank, Role = `Rank{rank}` })
			end
		end
		return { Roles = roles }
	end
	groupMethods.GetGroupInfoAsync = function(_self: any, groupId: number)
		local g = peerEnv.groups[groupId] or {}
		return {
			Id = groupId,
			Name = g.Name or `Group{groupId}`,
			EmblemUrl = "rbxassetid://0",
			Roles = g.Roles or { { Name = "Member", Rank = 1 }, { Name = "Owner", Rank = 255 } },
		}
	end
	rawset(groupService, "_methods", groupMethods)

	-- Ensure MessagingService routes PublishAsync to SubscribeAsync listeners synchronously
	local messaging = peerEnv.game:GetService("MessagingService")
	local msgSubs: { [string]: { (any) -> () } } = {}
	local msgMethods = rawget(messaging, "_methods") or {}
	local function subAsync(_self: any, topic: string, callback: (any) -> ())
		msgSubs[topic] = msgSubs[topic] or {}
		table.insert(msgSubs[topic], callback)
		return {
			Disconnect = function() end,
		}
	end
	local function pubAsync(_self: any, topic: string, data: any)
		local list = msgSubs[topic]
		if list then
			for _, cb in list do
				cb({ Data = data, Sent = 1700000000 })
			end
		end
	end
	msgMethods.SubscribeAsync = subAsync
	msgMethods.PublishAsync = pubAsync
	rawset(messaging, "_methods", msgMethods)
	rawset(messaging, "SubscribeAsync", subAsync)
	rawset(messaging, "PublishAsync", pubAsync)

	-- Ensure TeleportService has ReserveServer and GetPlayerPlaceInstanceAsync
	local teleport = peerEnv.game:GetService("TeleportService")
	local tpMethods = rawget(teleport, "_methods") or {}
	tpMethods.ReserveServer = function()
		return "reserved-access-code", "reserved-server-id"
	end
	tpMethods.GetPlayerPlaceInstanceAsync = function(_self: any, userId: number)
		if userId == 1 then
			return true, nil, 1, "job-1"
		elseif userId == 999 then
			error("Teleport lookup failed")
		end
		return false, nil, 100, "job-other"
	end
	rawset(teleport, "_methods", tpMethods)

	-- Ensure TextChatService has CanUserChatAsync, ChatInputBarConfiguration, and TextChannels (RBXGeneral, RBXSystem)
	local textChat = peerEnv.game:GetService("TextChatService")
	local tcMethods = rawget(textChat, "_methods") or {}
	tcMethods.CanUserChatAsync = function()
		if textChat._props._cannotChat then
			return false
		end
		return true
	end
	rawset(textChat, "_methods", tcMethods)
	if not textChat:FindFirstChildOfClass("ChatInputBarConfiguration") then
		local cib = peerEnv.createInstance("ChatInputBarConfiguration", textChat)
		cib.Enabled = true
	end
	if not textChat:FindFirstChild("TextChannels") then
		local channels = peerEnv.Instance.new("Folder", textChat)
		channels.Name = "TextChannels"
		local rbxGen = peerEnv.Instance.new("TextChannel", channels)
		rbxGen.Name = "RBXGeneral"
		rawset(rbxGen, "_methods", {
			SendAsync = function(self: any, msg: string, meta: string?)
				self._props._lastSent = msg
				self._props._lastMeta = meta
			end,
		})
		local rbxSys = peerEnv.Instance.new("TextChannel", channels)
		rbxSys.Name = "RBXSystem"
		rawset(rbxSys, "_methods", {
			DisplaySystemMessage = function(self: any, msg: string)
				self._props._lastSystemMsg = msg
			end,
		})
	end

	-- Ensure LocalizationService has GetCountryRegionForPlayerAsync
	local locService = peerEnv.game:GetService("LocalizationService")
	local locMethods = rawget(locService, "_methods") or {}
	locMethods.GetCountryRegionForPlayerAsync = function()
		return "US"
	end
	rawset(locService, "_methods", locMethods)

	-- Ensure MarketplaceService has PromptBulkPurchaseFinished and PromptBulkPurchase
	local market = peerEnv.game:GetService("MarketplaceService")
	market._props.PromptBulkPurchaseFinished = peerEnv:signal()
	local marketMethods = rawget(market, "_methods") or {}
	marketMethods.PromptBulkPurchase = function(_self: any, plr: any, items: any)
		market._props._lastBulkPurchase = { player = plr, items = items }
	end
	rawset(market, "_methods", marketMethods)

	-- Ensure AssetService has GetBundleDetailsAsync and rich CreateMeshPartAsync for AlphaWings/Crown
	local assetService = peerEnv.game:GetService("AssetService")
	local assetMethods = rawget(assetService, "_methods") or {}
	assetMethods.GetBundleDetailsAsync = function(_self: any, bundleId: number)
		if bundleId == 999 then
			error("Bundle error")
		end
		return {
			Id = bundleId,
			Name = `Bundle{bundleId}`,
			Items = {
				{ Id = bundleId * 10 + 1, Name = "Outfit", Type = "UserOutfit" },
			},
		}
	end
	assetMethods.CreateMeshPartAsync = function(_self: any, meshId: any)
		local mp = peerEnv.Instance.new("MeshPart")
		mp.MeshId = tostring(meshId or "")
		-- Build LeftWingRig.Wing1["Wing Beam"] for AlphaWings
		local leftRig = peerEnv.Instance.new("Bone", mp)
		leftRig.Name = "LeftWingRig"
		local wing1 = peerEnv.Instance.new("Bone", leftRig)
		wing1.Name = "Wing1"
		local beam = peerEnv.Instance.new("Beam", wing1)
		beam.Name = "Wing Beam"
		local rightRig = peerEnv.Instance.new("Bone", mp)
		rightRig.Name = "RightWingRig"
		local rwing1 = peerEnv.Instance.new("Bone", rightRig)
		rwing1.Name = "Wing1"
		mp.Size = Vector3.one
		return mp
	end
	rawset(assetService, "_methods", assetMethods)

	for _, audioId in { 123456, 999999 } do
		peerEnv.marketplace.products[audioId] = {
			AssetId = audioId,
			Name = `Audio{audioId}`,
			Description = "",
			PriceInRobux = 0,
			AssetTypeId = Enum.AssetType.Audio.Value,
			IsForSale = true,
		}
	end

	-- Ensure InsertService:LoadAsset returns tools, decals, parts, and models as needed
	local insertService = peerEnv.game:GetService("InsertService")
	local insertMethods = rawget(insertService, "_methods") or {}
	insertMethods.LoadAsset = function(_self: any, assetId: number)
		if assetId == 999998 then
			error("Asset is not authorized for this place")
		elseif assetId == 999997 then
			error("Generic insert failure")
		end
		local model = peerEnv.Instance.new("Model")
		model.Name = `Asset{assetId}`
		rawset(model, "_methods", {
			MakeJoints = function() end,
			BreakJoints = function() end,
			MoveTo = function(self: any, pos: Vector3)
				self._props.WorldPivot = CFrame.new(pos)
			end,
		})
		if assetId == 999999 then
			local pkg = peerEnv.createInstance("PackageLink", model)
			pkg.PackageId = "rbxassetid://132328169188520"
			local pkgRef = peerEnv.Instance.new("Folder", model)
			pkgRef.Name = "packageRef"
			peerEnv.Instance.new("ObjectValue", pkgRef)
			return model
		elseif assetId == 1800 then
			local decal = peerEnv.Instance.new("Decal", model)
			decal.Name = "face"
			decal.Texture = `rbxassetid://{assetId}`
			return model
		elseif assetId == 1100 then
			local shirt = peerEnv.Instance.new("Shirt", model)
			shirt.ShirtTemplate = `rbxassetid://{assetId}`
			return model
		elseif assetId == 1200 then
			local pants = peerEnv.Instance.new("Pants", model)
			pants.PantsTemplate = `rbxassetid://{assetId}`
			return model
		elseif assetId == 200 then
			local tshirt = peerEnv.Instance.new("ShirtGraphic", model)
			tshirt.Graphic = `rbxassetid://{assetId}`
			return model
		end
		local tool = peerEnv.Instance.new("Tool", model)
		tool.Name = `Tool{assetId}`
		local handle = peerEnv.Instance.new("Part", tool)
		handle.Name = "Handle"
		local acc = peerEnv.Instance.new("Accoutrement", model)
		acc.Name = `Hat{assetId}`
		local accHandle = peerEnv.Instance.new("Part", acc)
		accHandle.Name = "Handle"
		local accMesh = peerEnv.Instance.new("FileMesh", accHandle)
		accMesh.Name = "Mesh"
		accMesh.MeshType = Enum.MeshType.FileMesh
		accMesh.MeshId = "rbxassetid://123"
		accMesh.TextureId = "rbxassetid://456"
		accMesh.Scale = Vector3.one
		local s = peerEnv.Instance.new("Script", acc)
		s.Name = "HatScript"
		local decal = peerEnv.Instance.new("Decal", model)
		decal.Name = "face"
		decal.Texture = `rbxassetid://{assetId}`
		local shirt = peerEnv.Instance.new("Shirt", model)
		shirt.ShirtTemplate = `rbxassetid://{assetId}`
		local pants = peerEnv.Instance.new("Pants", model)
		pants.PantsTemplate = `rbxassetid://{assetId}`
		local tshirt = peerEnv.Instance.new("ShirtGraphic", model)
		tshirt.Graphic = `rbxassetid://{assetId}`
		return model
	end
	insertMethods.CreateMeshPartAsync = assetMethods.CreateMeshPartAsync
	rawset(insertService, "_methods", insertMethods)

	-- Ensure Players:CreateHumanoidModelFromDescriptionAsync returns a rich character model
	local players = peerEnv.Players
	local playersMethods = rawget(players, "_methods") or {}
	local function makeHumanoidModel(_self: any, _desc: any, rigType: any)
		local m = peerEnv._buildCharacter(peerEnv, {
			Name = "HumanoidModel",
			DisplayName = "HumanoidModel",
			CharacterAdded = peerEnv:signal(),
			CharacterAppearanceLoaded = peerEnv:signal(),
		}, if typeof(rigType) == "EnumItem" then rigType else Enum.HumanoidRigType.R15)
		local animScript = peerEnv.Instance.new("LocalScript", m)
		animScript.Name = "Animate"
		return m
	end
	playersMethods.CreateHumanoidModelFromDescription = makeHumanoidModel
	playersMethods.CreateHumanoidModelFromDescriptionAsync = makeHumanoidModel
	playersMethods.CreateHumanoidModelFromUserId = makeHumanoidModel
	playersMethods.CreateHumanoidModelFromUserIdAsync = makeHumanoidModel
	playersMethods.GetPlayerFromCharacter = function(self: any, character: any)
		for _, plr in self:GetPlayers() do
			if plr.Character == character then
				return plr
			end
		end
		return nil
	end
	rawset(players, "_methods", playersMethods)

	-- Ensure Workspace has GetRealPhysicsFPS and GetServerTimeNow
	local ws = peerEnv.workspace
	local wsMethods = rawget(ws, "_methods") or {}
	wsMethods.GetRealPhysicsFPS = function()
		return 60
	end
	wsMethods.GetServerTimeNow = function()
		return ws._props._serverTimeNow or 1700000000
	end
	wsMethods.Raycast = function()
		return nil
	end
	wsMethods.GetPartBoundsInRadius = function()
		return {}
	end
	rawset(ws, "_methods", wsMethods)

	-- Ensure Lighting has Atmosphere child for environment commands
	local lighting = peerEnv.game:GetService("Lighting")
	if not lighting:FindFirstChildOfClass("Atmosphere") then
		peerEnv.Instance.new("Atmosphere", lighting)
	end
end

local HEAD_ATTACHMENTS = { "HatAttachment", "HairAttachment", "FaceFrontAttachment", "FaceCenterAttachment" }
local HUMANOID_SCALES = { "BodyProportionScale", "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }
local UPPER_TORSO_ATTACHMENTS = { "BodyFrontAttachment", "BodyBackAttachment", "NeckRigAttachment" }
local R15_JOINT_ALIASES: { [string]: string } = {
	RightUpperArm = "RightShoulder",
	LeftUpperArm = "LeftShoulder",
	RightUpperLeg = "RightHip",
	LeftUpperLeg = "LeftHip",
}
local LIMB_NAMES = {
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
}
local R6_TORSO_MOTORS = { "Neck", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" }
local LOG_TYPES = {
	"DEBUG",
	"INFO",
	"WARN",
	"ERROR",
	"CHAT",
	"COMMAND",
	"JOIN",
	"LEAVE",
	"DAMAGE",
	"DEATH",
	"KILL",
	"PURCHASE",
}

local function buildCharacter(peerEnv: any, player: any, rigType: Enum.HumanoidRigType?): any
	peerEnv._buildCharacter = buildCharacter
	local instNew = peerEnv.Instance.new
	local char = instNew("Model")
	char.Name = player.Name

	local function makeMotor(name: string, parent: any)
		local m = instNew("Motor6D", parent)
		m.Name = name
		m.C0 = CFrame.identity
		m.C1 = CFrame.identity
		return m
	end

	local function decoratePart(part: any, joints: { any }?)
		rawset(part, "_methods", {
			CanSetNetworkOwnership = function()
				return true
			end,
			SetNetworkOwner = function() end,
			GetNetworkOwner = function()
				return player
			end,
			ApplyImpulse = function() end,
			ApplyAngularImpulse = function() end,
			GetMass = function(self: any)
				local s = self.Size
				return s.X * s.Y * s.Z
			end,
			GetJoints = function()
				return joints or {}
			end,
			GetConnectedParts = function(self: any)
				return { self }
			end,
		})
		return part
	end

	local root = decoratePart(instNew("Part", char))
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(0, 10, 0)
	root._props.AssemblyMass = 10
	char.PrimaryPart = root
	local rootAtt = instNew("Attachment", root)
	rootAtt.Name = "RootAttachment"
	rootAtt._props.WorldPosition = Vector3.new(0, 10, 0)
	local rootRigAtt = instNew("Attachment", root)
	rootRigAtt.Name = "RootRigAttachment"
	rootRigAtt._props.WorldPosition = Vector3.new(0, 10, 0)
	makeMotor("RootJoint", root)
	local rootLight = instNew("PointLight", root)
	rootLight.Enabled = true

	local head = decoratePart(instNew("MeshPart", char))
	head.Name = "Head"
	local origSize = instNew("Vector3Value", head)
	origSize.Name = "OriginalSize"
	origSize.Value = Vector3.new(2, 1, 1)
	local headMesh = instNew("SpecialMesh", head)
	headMesh.Name = "Mesh"
	headMesh.Scale = Vector3.one
	local face = instNew("Decal", head)
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	for _, attName in HEAD_ATTACHMENTS do
		local att = instNew("Attachment", head)
		att.Name = attName
		att._props.WorldPosition = Vector3.new(0, 10, 0)
	end

	local hum = instNew("Humanoid", char)
	hum._props.ApplyDescriptionFinished = peerEnv:signal()
	hum._props.Touched = peerEnv:signal()
	hum._props.RootPart = root
	hum._props.AutomaticScalingEnabled = true
	hum.UseJumpPower = true
	hum.RigType = rigType or Enum.HumanoidRigType.R15
	hum.DisplayName = player.DisplayName
	instNew("HumanoidDescription", hum)
	for _, scaleName in HUMANOID_SCALES do
		local nv = instNew("NumberValue", hum)
		nv.Name = scaleName
		nv.Value = 1
	end

	local animator = instNew("Animator", hum)
	rawset(animator, "_methods", {
		GetPlayingAnimationTracks = function()
			return {}
		end,
		LoadAnimation = function(_self: any, anim: any)
			local track = peerEnv.createInstance("AnimationTrack")
			track._props.Animation = anim
			track._props.Priority = Enum.AnimationPriority.Action
			track._props.Looped = false
			track._props.IsPlaying = false
			track._props.TimePosition = 0
			track._props.Stopped = peerEnv:signal()
			rawset(track, "_methods", {
				Play = function(t: any)
					t._props.IsPlaying = true
				end,
				Stop = function(t: any)
					t._props.IsPlaying = false
					t._props.Stopped:Fire()
				end,
				AdjustSpeed = function() end,
			})
			return track
		end,
	})

	rawset(hum, "_methods", {
		TakeDamage = function(self: any, amount: number)
			self.Health = math.max(0, (self.Health or 100) - amount)
		end,
		MoveTo = function() end,
		ChangeState = function(self: any, state: any)
			self._props._state = state
		end,
		GetState = function(self: any)
			return self._props._state or Enum.HumanoidStateType.Running
		end,
		SetStateEnabled = function(self: any, state: any, enabled: boolean)
			self._props._statesEnabled = self._props._statesEnabled or {}
			self._props._statesEnabled[state] = enabled
		end,
		UnequipTools = function() end,
		RemoveAccessories = function()
			for _, child in char:GetChildren() do
				if child:IsA("Accessory") then
					child:Destroy()
				end
			end
		end,
		GetAccessories = function()
			local out = {}
			for _, child in char:GetChildren() do
				if child:IsA("Accessory") then
					table.insert(out, child)
				end
			end
			return out
		end,
		AddAccessory = function(_self: any, acc: any)
			acc.Parent = char
		end,
		BuildRigFromAttachments = function() end,
		ReplaceBodyPartR15 = function() end,
		GetBodyPartR15 = function(_self: any, part: any)
			if part.Name == "LowerTorso" then
				return Enum.BodyPartR15.LowerTorso
			end
			return Enum.BodyPartR15.RootPart
		end,
		GetAppliedDescription = function(self: any)
			return self._props._description or instNew("HumanoidDescription")
		end,
		ApplyDescription = function(self: any, desc: any)
			self._props._description = desc
		end,
		ApplyDescriptionReset = function(self: any, desc: any)
			self._props._description = desc
		end,
	})

	-- Add R15 and R6 torso/limbs so both rig paths succeed
	local upperTorso = decoratePart(instNew("Part", char))
	upperTorso.Name = "UpperTorso"
	for _, attName in UPPER_TORSO_ATTACHMENTS do
		local att = instNew("Attachment", upperTorso)
		att.Name = attName
		att._props.WorldPosition = Vector3.new(0, 10, 0)
	end
	makeMotor("Waist", upperTorso)

	local lowerTorso = decoratePart(instNew("Part", char))
	lowerTorso.Name = "LowerTorso"
	makeMotor("Root", lowerTorso)
	local waistRigAtt = instNew("Attachment", lowerTorso)
	waistRigAtt.Name = "WaistRigAttachment"
	waistRigAtt._props.WorldPosition = Vector3.new(0, 10, 0)

	local neck = makeMotor("Neck", head)
	neck.Part0 = upperTorso
	neck.Part1 = head

	for _, limbName in LIMB_NAMES do
		local motor = makeMotor(limbName .. "Motor", nil)
		local limb = decoratePart(instNew("Part", char), { motor })
		limb.Name = limbName
		motor.Parent = limb
		motor.Part0 = upperTorso
		motor.Part1 = limb
		local alias = R15_JOINT_ALIASES[limbName]
		if alias then
			local mAlias = makeMotor(alias, limb)
			mAlias.Part0 = upperTorso
			mAlias.Part1 = limb
		end
		local origLimbSize = instNew("Vector3Value", limb)
		origLimbSize.Name = "OriginalSize"
		origLimbSize.Value = Vector3.new(1, 2, 1)
	end

	local torsoR6 = decoratePart(instNew("Part", char))
	torsoR6.Name = "Torso"
	for _, mName in R6_TORSO_MOTORS do
		local m = makeMotor(mName, torsoR6)
		m.Part0 = torsoR6
		m.Part1 = head
	end

	instNew("Shirt", char)
	instNew("Pants", char)
	instNew("ShirtGraphic", char)
	instNew("BodyColors", char)

	local acc = instNew("Accessory", char)
	acc.Name = "TestHat"
	local handle = decoratePart(instNew("Part", acc))
	handle.Name = "Handle"
	local mesh = instNew("SpecialMesh", handle)
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.Scale = Vector3.one
	local hatAtt = instNew("Attachment", handle)
	hatAtt.Name = "HatAttachment"
	instNew("SurfaceAppearance", handle)

	rawset(char, "_methods", {
		MakeJoints = function() end,
		BreakJoints = function() end,
		TranslateBy = function(self: any, delta: Vector3)
			self._props.WorldPivot = self:GetPivot() + delta
		end,
		GetPivot = function(self: any)
			return self._props.WorldPivot or CFrame.new(0, 10, 0)
		end,
		PivotTo = function(self: any, cf: CFrame)
			self._props.WorldPivot = cf
			if root then
				root.CFrame = cf
			end
		end,
		MoveTo = function(self: any, pos: Vector3)
			self._props.WorldPivot = CFrame.new(pos)
		end,
		ScaleTo = function(self: any, scale: number)
			self._props._scale = scale
		end,
		GetScale = function(self: any)
			return self._props._scale or 1
		end,
		GetBoundingBox = function()
			return CFrame.new(0, 10, 0), Vector3.new(4, 5, 2)
		end,
		GetExtentsSize = function()
			return Vector3.new(4, 5, 2)
		end,
	})

	char.Parent = peerEnv.workspace
	player.Character = char

	if player.FindFirstChild and not player:FindFirstChild("PlayerScripts") then
		local ps = peerEnv.createInstance("PlayerScripts", player)
		local pm = instNew("ModuleScript", ps)
		pm.Name = "PlayerModule"
		local controlsTable = {
			moveFunction = function() end,
		}
		rawset(pm, "_factory", function()
			return {
				GetControls = function()
					return controlsTable
				end,
			}
		end)
	end

	if player.SetAttribute then
		player:SetAttribute("_KSessionStart", 1700000000)
		player:SetAttribute("_KPlatform", "PC")
	end
	if player._props then
		player._props.FollowUserId = player._props.FollowUserId or 0
		player._props.AccountAge = player._props.AccountAge or 100
	end

	local playerMethods = rawget(player, "_methods") or {}
	playerMethods.Kick = function(self: any, msg: string?)
		self._props._kicked = msg or true
	end
	playerMethods.IsVerified = function()
		return false
	end
	playerMethods.HasAppearanceLoaded = function()
		return true
	end
	playerMethods.ClearCharacterAppearance = function() end
	playerMethods.GetNetworkPing = function()
		return 0.042
	end
	playerMethods.LoadCharacter = function(self: any)
		return buildCharacter(peerEnv, self, rigType)
	end
	playerMethods.LoadCharacterAsync = playerMethods.LoadCharacter
	playerMethods.LoadCharacterWithHumanoidDescription = function(self: any, _desc: any)
		return buildCharacter(peerEnv, self, rigType)
	end
	playerMethods.LoadCharacterWithHumanoidDescriptionAsync = playerMethods.LoadCharacterWithHumanoidDescription
	rawset(player, "_methods", playerMethods)

	player.CharacterAdded:Fire(char)
	player.CharacterAppearanceLoaded:Fire(char)
	return char
end

local function setupClientState(clientK: any, ch: Harness.MountedEnv)
	local cliEnv = ch.env
	local Flux = clientK.Flux
	local UI = clientK.UI
	clientK.LocalPlayer = cliEnv.Players.LocalPlayer
	clientK.Announce = function(args: any)
		clientK._lastAnnounce = args
	end
	clientK.Notify = function(args: any)
		clientK._lastNotify = args
		if type(args) == "table" and clientK.UI and clientK.UI.Hook then
			local hook = args[clientK.UI.Hook]
			if type(hook) == "table" and type(hook.Action) == "function" then
				hook.Action(true)
			end
		end
	end

	local function makeMockWindow(name: string, withLogFilters: boolean?)
		local frame = cliEnv.Instance.new("Frame")
		frame.Name = name
		frame.Visible = false
		local logTypeFilter = {}
		local filterTypeButtons = {}
		if withLogFilters then
			for _, logType in LOG_TYPES do
				logTypeFilter[logType] = Flux.signal(true)
				filterTypeButtons[logType] = { Activated = cliEnv:signal() }
			end
		end
		return {
			_instance = frame,
			logTypeFilter = logTypeFilter,
			filterTypeButtons = filterTypeButtons,
			updateList = function() end,
		}
	end

	local aboutPage = makeMockWindow("About")
	local commandsPage = makeMockWindow("Commands")
	local bansPage = makeMockWindow("Bans")
	local membersPage = makeMockWindow("Members")
	local serversPage = makeMockWindow("Servers")
	local logsPage = makeMockWindow("Logs", true)
	local settingsPage = makeMockWindow("Settings")
	local vipPage = makeMockWindow("VIP")
	local dashboardWindow = makeMockWindow("DashboardWindow")

	clientK.client = {
		Character = cliEnv:require(clientK.script.Client:WaitForChild("Character")),
		Explorer = {
			Show = function()
				clientK._explorerShown = true
			end,
		},
		UserFrame = function()
			local uf = cliEnv.Instance.new("Frame")
			local icon = cliEnv.Instance.new("ImageLabel", uf)
			icon.Name = "Icon"
			local fromFrame = cliEnv.Instance.new("Frame", uf)
			fromFrame.Name = "From"
			local fromLabel = cliEnv.Instance.new("TextLabel", fromFrame)
			fromLabel.Name = "From"
			fromLabel._props.AbsoluteSize = Vector2.new(100, 20)
			local badge = cliEnv.Instance.new("Frame", fromFrame)
			badge.Name = "Badge"
			return uf
		end,
		TopbarPlus = {
			setTopbarEnabled = function(enabled: boolean)
				clientK._topbarEnabled = enabled
			end,
		},
		CommandBar = {
			CompletionData = function()
				return {}
			end,
			show = function()
				clientK._cmdBarShown = true
			end,
			hide = function()
				clientK._cmdBarShown = false
			end,
		},
		updateCommandInput = function() end,
		bans = Flux.signal(clientK.Data.bans),
		logs = Flux.signal(clientK.Data.logs),
		members = Flux.signal(clientK.Data.members),
		servers = Flux.signal(clientK.Data.servers),
		rank = Flux.signal(math.huge),
		ready = true,
		hotkeys = {
			dashboard = {
				key = UI.signal(Enum.KeyCode.Quote),
				mods = UI.signal({}),
				callback = function()
					dashboardWindow._instance.Visible = not dashboardWindow._instance.Visible
				end,
			},
			commandBar = {
				key = UI.signal(Enum.KeyCode.Semicolon),
				mods = UI.signal({}),
				callback = function() end,
			},
		},
		settings = {
			prefix = Flux.signal({ ";" }),
		},
		playerPrefix = Flux.signal(";"),
		dashboardButton = {
			isSelected = false,
			select = function(self: any)
				self.isSelected = true
				dashboardWindow._instance.Visible = true
			end,
			deselect = function(self: any)
				self.isSelected = false
				dashboardWindow._instance.Visible = false
			end,
		},
		dashboard = {
			[1] = true,
			Window = dashboardWindow,
			About = aboutPage,
			Commands = commandsPage,
			Bans = bansPage,
			Members = membersPage,
			Servers = serversPage,
			Logs = logsPage,
			Settings = settingsPage,
			VIP = vipPage,
			Market = vipPage,
			Tabs = {
				JumpTo = function(self: any, page: any)
					self._currentPage = page
				end,
				_pages = {
					JumpTo = function() end,
				},
				_containerCache = {},
			},
		},
		commandsWindowVisible = function(vis: boolean?)
			commandsPage._instance.Visible = if vis ~= nil then vis else not commandsPage._instance.Visible
		end,
		updateInterfaceAuth = function()
			clientK._interfaceAuthUpdated = true
		end,
	}
end

local function createSimCluster(serverGlobals: { [string]: any }?, serverOnly: boolean?)
	local world = sert.sim.new({ backing = true })
	local server = world:server()
	local client1 = server:client(1, "CreatorPlr")
	local client2 = server:client(2, "TargetPlr")

	local sh = Harness.newPeerEnv(server, { isStudio = false })
	decorateEnvironment(sh.env)

	local srvP1 = sh.env.Players:GetPlayerByUserId(1)
	local srvP2 = sh.env.Players:GetPlayerByUserId(2)
	srvP1.Name = "CreatorPlr"
	srvP1.DisplayName = "CreatorPlr"
	srvP2.Name = "TargetPlr"
	srvP2.DisplayName = "TargetPlr"
	if not srvP1:FindFirstChildOfClass("PlayerGui") then
		sh.env.createInstance("PlayerGui", srvP1)
	end

	buildCharacter(sh.env, srvP1)
	buildCharacter(sh.env, srvP2)

	local ch1: any, ch2: any
	if not serverOnly then
		ch1 = Harness.newPeerEnv(client1, { isClient = true })
		ch2 = Harness.newPeerEnv(client2, { isClient = true })
		decorateEnvironment(ch1.env)
		decorateEnvironment(ch2.env)

		ch1.env.Players.LocalPlayer.Name = "CreatorPlr"
		ch1.env.Players.LocalPlayer.DisplayName = "CreatorPlr"
		ch2.env.Players.LocalPlayer.Name = "TargetPlr"
		ch2.env.Players.LocalPlayer.DisplayName = "TargetPlr"

		buildCharacter(ch1.env, ch1.env.Players.LocalPlayer)
		buildCharacter(ch2.env, ch2.env.Players.LocalPlayer)
		local cliP2OnC1 = ch1.env.Players:GetPlayerByUserId(2)
		if cliP2OnC1 then
			cliP2OnC1.Name = "TargetPlr"
			cliP2OnC1.DisplayName = "TargetPlr"
			buildCharacter(ch1.env, cliP2OnC1)
		end
	end

	for name, value in serverGlobals or {} do
		sh.env.globals[name] = value
	end
	local _K = sh:requireK()
	_K.Data.creatorId = 1
	_K.Data.SEPARATE_DATASTORE = false
	_K.LoadScript = function(source: string, _kind: string, parent: any?)
		local s = sh.env.Instance.new("Script", parent)
		s.Name = source
		return s
	end
	local mockStores: { [string]: any } = {}
	_K.Data.Store = {
		updateAsync = function(key: string, fn: (any) -> any)
			mockStores[key] = fn(mockStores[key] or {})
			return true, mockStores[key]
		end,
		removeAsync = function(_key: string)
			return true
		end,
		setAsync = function(_key: string, _val: any)
			return true
		end,
		getAsync = function(_key: string)
			return true, nil
		end,
	}
	Harness.seedRoles(_K.Data)
	_K.Auth.userRoleAdd(1, "creator")
	_K.Auth.userRoleAdd(1, "vip")

	local clientK: any
	if not serverOnly then
		clientK = ch1:requireK()
		clientK.Data.creatorId = 1
		Harness.seedRoles(clientK.Data)
		clientK.Auth.userRoleAdd(1, "creator")
		clientK.Auth.userRoleAdd(1, "vip")
		setupClientState(clientK, ch1)
	end
	world:run(0.1)

	return {
		world = world,
		server = server,
		client1 = client1,
		client2 = client2,
		sh = sh,
		ch1 = ch1,
		ch2 = ch2,
		srvP1 = srvP1,
		srvP2 = srvP2,
		_K = _K,
		clientK = clientK,
		runSrv = function(raw: string)
			sh.env.task.spawn(function()
				_K.Process.runCommands(_K, 1, raw)
			end)
		end,
		runCli = function(raw: string)
			ch1.env.task.spawn(function()
				clientK.Process.runCommands(clientK, 1, raw)
			end)
		end,
	}
end

-- utf8 whose graphemes join a combining mark to the character before it, like Roblox
local function clusteringUtf8()
	local clustering = setmetatable({}, { __index = utf8 })
	clustering.graphemes = function(text: string)
		local spans = {}
		for first, code in utf8.codes(text) do
			local last = first + #utf8.char(code) - 1
			if code >= 0x300 and code <= 0x36F and #spans > 0 then
				spans[#spans][2] = last
			else
				table.insert(spans, { first, last })
			end
		end
		local i = 0
		return function()
			i += 1
			local span = spans[i]
			if span then
				return span[1], span[2]
			end
			return nil
		end
	end
	return clustering
end

return {
	decorateEnvironment = decorateEnvironment,
	buildCharacter = buildCharacter,
	setupClientState = setupClientState,
	createSimCluster = createSimCluster,
	clusteringUtf8 = clusteringUtf8,
}
