-- Server-authoritative story runner. Clients send intent (start/choose/menu);
-- the server owns health, calm, items and decides every outcome.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Engine = require(Shared:WaitForChild("Engine"))
local Scenarios = require(Shared:WaitForChild("Scenarios"))

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

local store = DataStoreService:GetDataStore("Endings_v1")

local sessions = {} -- [Player] = engine state
local progress = {} -- [Player] = { [scenarioId] = { [endingNodeId] = true } }
local lastCall = {} -- [Player] = os.clock() of last request

local function loadProgress(player)
	local ok, data = pcall(function()
		return store:GetAsync("u" .. player.UserId)
	end)
	progress[player] = (ok and type(data) == "table") and data or {}
end

local function saveProgress(player)
	local data = progress[player]
	if not data then return end
	local ok, err = pcall(function()
		store:SetAsync("u" .. player.UserId, data)
	end)
	if not ok then warn("[Story] save failed: " .. tostring(err)) end
end

local function menuPayload(player)
	local list = {}
	for _, s in ipairs(Scenarios) do
		local total = 0
		for _, node in pairs(s.nodes) do
			if node.ending then total += 1 end
		end
		local found = 0
		for _ in pairs((progress[player] or {})[s.id] or {}) do found += 1 end
		list[#list + 1] = {
			id = s.id, title = s.title, place = s.place, disaster = s.disaster,
			icon = s.icon, difficulty = s.difficulty, blurb = s.blurb,
			endingsFound = found, endingsTotal = total,
		}
	end
	return list
end

local function recordEnding(player, scenarioId, nodeId)
	local p = progress[player]
	if not p then return end
	p[scenarioId] = p[scenarioId] or {}
	if not p[scenarioId][nodeId] then
		p[scenarioId][nodeId] = true
		task.spawn(saveProgress, player)
	end
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
		return { menu = menuPayload(player) }

	elseif action == "start" then
		local scenario = type(arg) == "string" and byId[arg]
		if not scenario then return { error = "unknown scenario" } end
		local state = Engine.new(scenario)
		sessions[player] = state
		return Engine.view(scenario, state)

	elseif action == "choose" then
		local state = sessions[player]
		if not state or type(arg) ~= "number" then return { error = "no active story" } end
		local scenario = byId[state.scenarioId]
		local ok, why = Engine.choose(scenario, state, math.floor(arg))
		if not ok then return { error = why } end
		local view = Engine.view(scenario, state)
		if view.ending then
			recordEnding(player, scenario.id, state.node)
			view.ending.steps = state.steps
		end
		return view
	end
	return { error = "bad action" }
end

Players.PlayerAdded:Connect(loadProgress)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(loadProgress, player) end

Players.PlayerRemoving:Connect(function(player)
	saveProgress(player)
	sessions[player], progress[player], lastCall[player] = nil, nil, nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do saveProgress(player) end
end)
