--!nocheck
-- Pure story engine. No Roblox APIs, so it can be unit-tested outside Studio
-- (see tools/test_story.py). Runs on the server; clients only ever see views.

local Engine = {}

local MAX_HEALTH = 100
local MAX_CALM = 100
local PANIC_THRESHOLD = 25 -- at or below this calm, risky choices get harder
local PANIC_PENALTY = 0.15

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

-- loadout (optional): { items = {"knife"}, healthBonus = 50 } from purchased packs.
function Engine.new(scenario, loadout)
	loadout = loadout or {}
	local maxHealth = MAX_HEALTH + (loadout.healthBonus or 0)
	local items = {}
	for _, item in ipairs(loadout.items or {}) do items[item] = true end
	return {
		scenarioId = scenario.id,
		node = scenario.start,
		maxHealth = maxHealth,
		health = maxHealth,
		calm = MAX_CALM,
		items = items,
		flags = {},
		note = nil,
		steps = 0,
		path = { scenario.start },
		finished = false,
	}
end

local function meetsRequirements(state, req)
	if not req then return true end
	if req.items then
		for _, item in ipairs(req.items) do
			if not state.items[item] then
				return false, "Needs: " .. item
			end
		end
	end
	if req.flags then
		for _, flag in ipairs(req.flags) do
			if not state.flags[flag] then
				return false, "Not possible right now"
			end
		end
	end
	if req.notFlags then
		for _, flag in ipairs(req.notFlags) do
			if state.flags[flag] then
				return false, "Not possible right now"
			end
		end
	end
	return true
end

local function applyEffects(state, fx)
	if not fx then return end
	if fx.health then state.health = clamp(state.health + fx.health, 0, state.maxHealth) end
	if fx.calm then state.calm = clamp(state.calm + fx.calm, 0, MAX_CALM) end
	if fx.give then
		for _, item in ipairs(fx.give) do state.items[item] = true end
	end
	if fx.take then
		for _, item in ipairs(fx.take) do state.items[item] = nil end
	end
	if fx.set then
		for _, flag in ipairs(fx.set) do state.flags[flag] = true end
	end
end

local function sortedKeys(t)
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end
	table.sort(keys)
	return keys
end

-- What the client is allowed to see.
function Engine.view(scenario, state)
	local node = scenario.nodes[state.node]
	local view = {
		scenarioId = scenario.id,
		title = scenario.title,
		nodeId = state.node,
		text = node.text,
		fx = node.fx or "none",
		note = state.note,
		health = state.health,
		maxHealth = state.maxHealth,
		calm = state.calm,
		items = sortedKeys(state.items),
		panicked = state.calm <= PANIC_THRESHOLD,
		choices = {},
	}
	if node.ending then
		view.ending = {
			kind = node.ending.kind,
			title = node.ending.title,
			lesson = node.lesson or scenario.lesson,
		}
		return view
	end
	for i, choice in ipairs(node.choices) do
		local ok, why = meetsRequirements(state, choice.requires)
		if ok or not choice.hiddenIfLocked then
			view.choices[#view.choices + 1] = {
				index = i,
				text = choice.text,
				locked = not ok,
				lockReason = why,
				risky = choice.chance ~= nil,
				hold = choice.hold,
			}
		end
	end
	return view
end

-- Returns true, or false + reason. Mutates state.
function Engine.choose(scenario, state, index, rng)
	if state.finished then return false, "Story already finished" end
	local node = scenario.nodes[state.node]
	local choice = node.choices and node.choices[index]
	if not choice then return false, "Invalid choice" end
	local ok, why = meetsRequirements(state, choice.requires)
	if not ok then return false, why end

	rng = rng or math.random
	state.steps = state.steps + 1
	state.note = choice.note
	applyEffects(state, choice.effects)

	local target = choice.next
	if choice.chance then
		local p = choice.chance.p
		if state.calm <= PANIC_THRESHOLD then p = p - PANIC_PENALTY end
		local boostItems = choice.chance.boostItems or { choice.chance.boostItem }
		for _, item in ipairs(boostItems) do
			if state.items[item] then p = p + (choice.chance.boost or 0.2) break end
		end
		p = clamp(p, 0.05, 0.95)
		if rng() < p then
			target = choice.chance.win
			if choice.chance.winNote then state.note = choice.chance.winNote end
		else
			target = choice.chance.lose
			applyEffects(state, choice.chance.loseEffects)
			if choice.chance.loseNote then state.note = choice.chance.loseNote end
		end
	end

	-- Fatal injuries override whatever node the choice pointed at.
	if state.health <= 0 then
		target = scenario.deathNode
		state.note = (state.note and (state.note .. " ") or "") .. "Your injuries are too severe."
	end

	state.node = target
	state.path[#state.path + 1] = target
	if scenario.nodes[target].ending then state.finished = true end
	return true
end

-- Walks the graph and returns a list of human-readable problems (empty = ok).
function Engine.validate(scenario)
	local problems = {}
	local function err(msg) problems[#problems + 1] = scenario.id .. ": " .. msg end
	local nodes = scenario.nodes
	if not nodes[scenario.start] then err("missing start node " .. tostring(scenario.start)) end
	if not (scenario.deathNode and nodes[scenario.deathNode]) then err("missing deathNode") end
	local function check(from, to)
		if not nodes[to] then err(from .. " -> missing node '" .. tostring(to) .. "'") end
	end
	for id, node in pairs(nodes) do
		if node.ending then
			if not node.lesson and not scenario.lesson then err(id .. " ending has no lesson") end
		else
			if not node.choices or #node.choices == 0 then err(id .. " has no choices and is not an ending") end
			for i, c in ipairs(node.choices or {}) do
				if c.chance then
					check(id .. "#" .. i, c.chance.win)
					check(id .. "#" .. i, c.chance.lose)
				else
					check(id .. "#" .. i, c.next)
				end
			end
		end
	end
	-- reachability
	local seen, stack = {}, { scenario.start }
	while #stack > 0 do
		local id = table.remove(stack)
		if not seen[id] and nodes[id] then
			seen[id] = true
			for _, c in ipairs(nodes[id].choices or {}) do
				if c.chance then
					stack[#stack + 1] = c.chance.win
					stack[#stack + 1] = c.chance.lose
				else
					stack[#stack + 1] = c.next
				end
			end
		end
	end
	seen[scenario.deathNode] = true -- reached via health <= 0
	for id in pairs(nodes) do
		if not seen[id] then err("unreachable node '" .. id .. "'") end
	end
	return problems
end

return Engine
