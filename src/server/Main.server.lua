-- Server-authoritative story runner. Clients send intent (start/choose/menu);
-- the server owns health, calm, items and decides every outcome.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Engine = require(Shared:WaitForChild("Engine"))
local Scenarios = require(Shared:WaitForChild("Scenarios"))
local Shop = require(Shared:WaitForChild("Shop"))
local Config = require(Shared:WaitForChild("Config"))
local Lighting = game:GetService("Lighting")
local Stage = require(script.Parent:WaitForChild("Stage"))
local Worlds = script.Parent:WaitForChild("Worlds")

local packById = {}
for _, pack in ipairs(Shop) do packById[pack.id] = pack end
local packByProduct = {}
for _, pack in ipairs(Shop) do
	if pack.productId ~= 0 then packByProduct[pack.productId] = pack end
end

Lighting.Ambient = Color3.fromRGB(95, 95, 110) -- indoor stages are lit by lamps plus this
Lighting.OutdoorAmbient = Color3.fromRGB(110, 110, 120)

-- Fail loudly at server start if a scenario graph is broken.
local byId = {}
for _, scenario in ipairs(Scenarios) do
	byId[scenario.id] = scenario
	for _, problem in ipairs(Engine.validate(scenario)) do
		warn("[Story] " .. problem)
	end
end

local remote = Instance.new("RemoteFunction")
remote.Name = "StoryRemote"
remote.Parent = ReplicatedStorage

local storyUpdate = Instance.new("RemoteEvent")
storyUpdate.Name = "StoryUpdate"
storyUpdate.Parent = ReplicatedStorage

local inventoryChanged = Instance.new("RemoteEvent")
inventoryChanged.Name = "InventoryChanged"
inventoryChanged.Parent = ReplicatedStorage

local store = DataStoreService:GetDataStore("Profile_v1")

local sessions = {} -- [Player] = engine state
local profiles = {} -- [Player] = { endings = {...}, inventory = {[packId]=count}, receipts = {[id]=true} }
local equipped = {} -- [Player] = { [packId] = true }  (this visit only)
local lastCall = {} -- [Player] = os.clock() of last request
local holds = {} -- [Player] = { index, at } for press-and-hold buttons in the UI

local function loadProfile(player)
	local ok, data = pcall(function()
		return store:GetAsync("u" .. player.UserId)
	end)
	if not ok then
		warn("[Story] load failed: " .. tostring(data))
		data = nil -- play with a blank profile this session; do not overwrite saved data
		profiles[player] = { endings = {}, inventory = {}, receipts = {}, readOnly = true }
		return
	end
	data = type(data) == "table" and data or {}
	data.endings = data.endings or {}
	data.inventory = data.inventory or {}
	data.receipts = data.receipts or {}
	profiles[player] = data
end

local function saveProfile(player)
	local data = profiles[player]
	if not data or data.readOnly then return true end
	local ok, err = pcall(function()
		store:SetAsync("u" .. player.UserId, data)
	end)
	if not ok then warn("[Story] save failed: " .. tostring(err)) end
	return ok
end

local function inventoryPayload(player)
	local profile = profiles[player]
	local list = {}
	for _, pack in ipairs(Shop) do
		list[#list + 1] = {
			id = pack.id, name = pack.name, desc = pack.desc,
			owned = profile and profile.inventory[pack.id] or 0,
			equipped = (equipped[player] or {})[pack.id] == true,
			forSale = pack.productId ~= 0 or RunService:IsStudio(),
		}
	end
	return list
end

local function grantPack(player, packId)
	local profile = profiles[player]
	if not profile then return false end
	profile.inventory[packId] = (profile.inventory[packId] or 0) + 1
	inventoryChanged:FireClient(player, inventoryPayload(player))
	return true
end

local function menuPayload(player)
	local list = {}
	for _, s in ipairs(Scenarios) do
		local total = 0
		for _, node in pairs(s.nodes) do
			if node.ending then total += 1 end
		end
		local found = 0
		for _ in pairs(((profiles[player] or {}).endings or {})[s.id] or {}) do found += 1 end
		list[#list + 1] = {
			id = s.id, title = s.title, place = s.place, disaster = s.disaster,
			icon = s.icon, difficulty = s.difficulty, blurb = s.blurb,
			endingsFound = found, endingsTotal = total,
		}
	end
	return list
end

local function recordEnding(player, scenarioId, nodeId)
	local profile = profiles[player]
	if not profile then return end
	local p = profile.endings
	p[scenarioId] = p[scenarioId] or {}
	if not p[scenarioId][nodeId] then
		p[scenarioId][nodeId] = true
		task.spawn(saveProfile, player)
	end
end

-- Builds the view for the current node, placing choices in the 3D stage if there is one.
local applyChoice
local function buildView(player, scenario, state)
	local view = Engine.view(scenario, state)
	if Stage.active(player) then
		Stage.apply(player, view, function(who, index, nodeId)
			-- Prompt path: ignore stale prompts from an earlier node.
			local st = sessions[who]
			if not st or st.node ~= nodeId then return end
			local result = applyChoice(who, index, "world")
			if result and not result.error then storyUpdate:FireClient(who, result) end
		end)
	end
	return view
end

-- via = "ui" (button; hold time is verified here) or "world" (ProximityPrompt; Roblox enforced the hold).
function applyChoice(player, index, via)
	local state = sessions[player]
	if not state or type(index) ~= "number" then return { error = "no active story" } end
	local scenario = byId[state.scenarioId]
	index = math.floor(index)
	local choice = scenario.nodes[state.node].choices and scenario.nodes[state.node].choices[index]
	if choice and choice.hold and via == "ui" then
		local h = holds[player]
		holds[player] = nil
		if not h or h.index ~= index or os.clock() - h.at < choice.hold - 0.4 then
			return { error = "hold longer" }
		end
	end
	local ok, why = Engine.choose(scenario, state, index)
	if not ok then return { error = why } end
	local view = buildView(player, scenario, state)
	if view.ending then
		recordEnding(player, scenario.id, state.node)
		view.ending.steps = state.steps
	end
	return view
end

remote.OnServerInvoke = function(player, action, arg)
	-- Basic rate limit so a client cannot spam the server.
	local now = os.clock()
	if lastCall[player] and now - lastCall[player] < 0.15 then
		return { error = "slow down" }
	end
	lastCall[player] = now

	if action == "menu" then
		sessions[player] = nil
		holds[player] = nil
		Stage.leave(player, true)
		return { menu = menuPayload(player), shopEnabled = Config.ShopEnabled, packs = Config.ShopEnabled and inventoryPayload(player) or nil }

	elseif (action == "equip" or action == "buy") and not Config.ShopEnabled then
		return { error = "shop disabled" }

	elseif action == "equip" then
		-- arg = { id = packId, on = bool }
		local profile = profiles[player]
		if not profile or type(arg) ~= "table" or not packById[arg.id] then return { error = "bad pack" } end
		equipped[player] = equipped[player] or {}
		equipped[player][arg.id] = (arg.on == true and (profile.inventory[arg.id] or 0) > 0) or nil
		return { packs = inventoryPayload(player) }

	elseif action == "buy" then
		local pack = type(arg) == "string" and packById[arg]
		if not pack then return { error = "unknown pack" } end
		if pack.productId ~= 0 then
			MarketplaceService:PromptProductPurchase(player, pack.productId)
			return { prompted = true }
		elseif RunService:IsStudio() then
			grantPack(player, pack.id) -- free test grant, Studio only
			return { packs = inventoryPayload(player) }
		end
		return { error = "not for sale yet" }

	elseif action == "start" then
		local scenario = type(arg) == "string" and byId[arg]
		if not scenario then return { error = "unknown scenario" } end
		-- Consume equipped packs (one use each) and build the starting loadout.
		local loadout = { items = {}, healthBonus = 0 }
		local profile = profiles[player]
		for packId in pairs(Config.ShopEnabled and equipped[player] or {}) do
			local pack = packById[packId]
			if pack and profile and (profile.inventory[packId] or 0) > 0 then
				profile.inventory[packId] -= 1
				for _, item in ipairs(pack.items) do table.insert(loadout.items, item) end
				loadout.healthBonus += pack.healthBonus
				if profile.inventory[packId] == 0 then equipped[player][packId] = nil end
			end
		end
		if next(loadout.items) or loadout.healthBonus > 0 then
			task.spawn(saveProfile, player)
			inventoryChanged:FireClient(player, inventoryPayload(player))
		end
		local state = Engine.new(scenario, loadout)
		sessions[player] = state
		holds[player] = nil
		Stage.leave(player, false)
		local worldModule = scenario.world and Worlds:FindFirstChild(scenario.world)
		if worldModule then
			if not Stage.enter(player, require(worldModule)) then warn("[Story] no free stage slot") end
		end
		return buildView(player, scenario, state)

	elseif action == "holdbegin" then
		if type(arg) == "number" then holds[player] = { index = math.floor(arg), at = os.clock() } end
		return { ok = true }

	elseif action == "choose" then
		return applyChoice(player, arg, "ui")
	end
	return { error = "bad action" }
end

-- Robux purchases. Must be idempotent: Roblox may call this more than once
-- for the same PurchaseId, and only a granted+saved purchase may return Granted.
MarketplaceService.ProcessReceipt = function(info)
	if not Config.ShopEnabled then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local profile = profiles[player]
	if not profile or profile.readOnly then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local key = tostring(info.PurchaseId)
	if profile.receipts[key] then return Enum.ProductPurchaseDecision.PurchaseGranted end
	local pack = packByProduct[info.ProductId]
	if not pack then
		warn("[Shop] receipt for unknown product " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	profile.receipts[key] = true
	profile.inventory[pack.id] = (profile.inventory[pack.id] or 0) + 1
	if not saveProfile(player) then
		profile.receipts[key] = nil
		profile.inventory[pack.id] -= 1
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	inventoryChanged:FireClient(player, inventoryPayload(player))
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Put the player back on their stage if they respawn mid-story.
local function watchCharacter(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		Stage.recall(player)
	end)
end
Players.PlayerAdded:Connect(watchCharacter)
for _, player in ipairs(Players:GetPlayers()) do watchCharacter(player) end
Stage.setup()

Players.PlayerAdded:Connect(loadProfile)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(loadProfile, player) end

Players.PlayerRemoving:Connect(function(player)
	saveProfile(player)
	sessions[player], profiles[player], equipped[player], lastCall[player], holds[player] = nil, nil, nil, nil, nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do saveProfile(player) end
end)
