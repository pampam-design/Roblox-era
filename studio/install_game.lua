-- SURVIVE THE DISASTER: one-time installer.
-- In Roblox Studio: View > Command Bar, paste this whole script, press Enter.
-- It (re)creates: ReplicatedStorage.Shared, ServerScriptService.Server and
-- StarterPlayerScripts.Client. Re-running replaces those three folders.
-- Then press Play. (Studio only: Game Settings > Security > "Enable Studio
-- Access to API Services" if you want endings to save.)

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if f and f:IsA("Folder") then return f end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- wipe any previous install
for _, spec in ipairs({
	{ game:GetService("ReplicatedStorage"), "Shared" },
	{ game:GetService("ServerScriptService"), "Server" },
	{ game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"), "Client" },
}) do
	local old = spec[1]:FindFirstChild(spec[2])
	if old then old:Destroy() end
end

local function make(class, name, parent, source)
	local inst = Instance.new(class)
	inst.Name = name
	inst.Source = source
	inst.Parent = parent
	return inst
end

local Lighting = game:GetService("Lighting")
Lighting.ClockTime = 14
Lighting.Brightness = 2

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local Shared = folder(RS, "Shared")
local Server = folder(SSS, "Server")
local Worlds = folder(Server, "Worlds")
local Client = folder(SPS, "Client")
local scenarios

local _ = make("ModuleScript", "Engine", Shared, [=====[
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
]=====])

local _ = make("ModuleScript", "Config", Shared, [=====[
--!nocheck
return {
	-- Master switch for the Robux starter-pack shop. While false: no shop button,
	-- the server rejects buy/equip, packs are never applied to a run, and no
	-- purchase receipts are processed.
	ShopEnabled = false,
}
]=====])

local _ = make("ModuleScript", "Shop", Shared, [=====[
--!nocheck
-- Starter packs sold for Robux as consumable Developer Products.
-- Each pack is used up by one story run. Buying does NOT gate any ending:
-- tools/test_story.py verifies every ending is reachable with no packs.
--
-- SETUP: create a Developer Product per pack in the Creator Dashboard and put
-- its id in productId. While productId is 0, packs are free in Studio only
-- (for testing) and unavailable in the live game.
return {
	{
		id = "supplies",
		name = "Supply Pack",
		desc = "Start with water and food.",
		items = { "water", "food" },
		healthBonus = 0,
		productId = 0,
	},
	{
		id = "knife",
		name = "Survival Knife",
		desc = "Start with a knife. Opens extra options in some scenes.",
		items = { "knife" },
		healthBonus = 0,
		productId = 0,
	},
	{
		id = "vitality",
		name = "Extra HP",
		desc = "Start with 150 health instead of 100.",
		items = {},
		healthBonus = 50,
		productId = 0,
	},
	{
		id = "bundle",
		name = "Ultimate Survivor Bundle",
		desc = "Water, food, a knife, and 150 health.",
		items = { "water", "food", "knife" },
		healthBonus = 50,
		productId = 0,
	},
}
]=====])

scenarios = make("ModuleScript", "Scenarios", Shared, [=====[
--!nocheck
-- Ordered list of scenarios. To add a new one, create a module in this folder
-- and add it here (see README.md for the node format).
return {
	require(script.Classroom),
	require(script.Subway),
	require(script.Wildfire),
	require(script.Tsunami),
	require(script.Zombies),
	require(script.Nuclear),
}
]=====])

local _ = make("ModuleScript", "Classroom", scenarios, [=====[
--!nocheck
-- Scenario: earthquake during a maths lesson.
return {
	id = "classroom",
	title = "Shaking Ground",
	place = "Classroom",
	disaster = "Earthquake",
	icon = "🏫",
	difficulty = "Easy",
	blurb = "Second floor, Room 204. Period 3 maths. The floor starts to move.",
	world = "Classroom", -- 3D stage in src/server/Worlds/Classroom.lua
	start = "start",
	deathNode = "death",
	lesson = "In an earthquake: Drop, Cover, and Hold On. Stay put until the shaking stops.",
	nodes = {
		start = {
			fx = "calm",
			text = "Period 3, Room 204. Ms. Okafor is mid-sentence about quadratic equations when your pencil rolls off the desk. Then the lights sway. A low rumble rises through the floor and the windows begin to rattle.\n\n\"Is that a truck?\" someone whispers. Then the whole room lurches sideways.",
			choices = {
				{ text = "Drop under your desk, grab a leg and hold on.", next = "under_desk", hold = 3, effects = { calm = -5 } },
				{ text = "Sprint for the door before the roof comes down.", next = "run_door", effects = { health = -25, calm = -20 }, note = "You get knocked into the doorframe by the stampede." },
				{ text = "Stand in the doorway. You heard that's the safest spot.", next = "doorway", effects = { health = -15, calm = -10 }, note = "The door slams back and forth, hitting your shoulder." },
			},
		},

		under_desk = {
			fx = "quake",
			text = "Under the desk you can hear everything: books hitting the floor, a ceiling tile cracking, someone screaming. The desk skids across the room but you hold on tight.\n\nAcross the aisle, Jay is standing frozen with his hands over his ears. A light fixture swings above his head.",
			choices = {
				{ text = "Reach out and pull Jay under your desk.", next = "shaking_stops", effects = { health = -10, calm = -10 }, note = "A ceiling tile clips your arm, but Jay is under cover." },
				{ text = "Shout at Jay to get down, but stay put.", next = "shaking_stops", chance = { p = 0.5, win = "shaking_stops", lose = "shaking_stops", loseEffects = { calm = -15 }, winNote = "Jay snaps out of it and ducks under his own desk just in time.", loseNote = "Jay does not move. You watch the fixture fall near him and it is hard to look away." } },
				{ text = "Hold on and keep your head down. Survive first.", next = "shaking_stops", hold = 3, effects = { calm = -10 } },
			},
		},

		run_door = {
			fx = "quake",
			text = "You make it three steps before the floor throws you against a bookcase. The corridor is full of kids pushing the same way. Something heavy lands near your feet. Dust fills the air.\n\nThe shaking is easing off. Your ears are ringing.",
			choices = {
				{ text = "Crawl back into the classroom and get under a desk.", next = "shaking_stops", effects = { health = -5 } },
				{ text = "Keep pushing toward the stairwell.", next = "hallway_crush" },
			},
		},

		doorway = {
			fx = "quake",
			text = "You brace in the doorway. Modern doorframes are no stronger than the rest of the building, and the door keeps swinging. You get pinned for a moment, then freed when a classmate drags you down to the floor.\n\n\"Get DOWN!\" she yells. Shortly after, the shaking stops.",
			choices = {
				{ text = "Check yourself over, then look around the room.", next = "shaking_stops" },
			},
		},

		hallway_crush = {
			fx = "dark",
			text = "The stairwell door is jammed with people. Someone trips and the crowd surges. You are pinned against the wall, struggling to breathe, until a teacher's voice cuts through: \"STOP PUSHING. Everyone step back!\"",
			choices = {
				{ text = "Step back and help calm the people around you.", next = "shaking_stops", effects = { calm = 10, health = -5 }, note = "The crowd loosens a little. People can breathe again." },
				{ text = "Climb over the pile to get out first.", next = "death", effects = { health = -80 }, note = "You fall into the crush." },
			},
		},

		shaking_stops = {
			fx = "calm",
			text = "Silence. Then coughing, crying, a phone buzzing somewhere. The shaking has stopped. The lights are out, the fire alarm is howling, and dust hangs in the air.\n\nMs. Okafor stands by the whiteboard, pale but steady. \"Everyone listen. We are going to leave the building calmly. Take one thing each, but nothing heavy. Go.\"",
			choices = {
				{ text = "Grab the first-aid kit from the wall.", next = "corridor", effects = { give = { "first-aid kit" } } },
				{ text = "Grab your backpack: it has a torch and a water bottle.", next = "corridor", effects = { give = { "torch", "water" } } },
				{ text = "Take nothing and head for the door right now.", next = "corridor", effects = { calm = 5 } },
			},
		},

		corridor = {
			fx = "dark",
			text = "The corridor is half-dark and littered with ceiling tiles and glass. At one end the stairwell is blocked by a collapsed wall. At the other end, a back staircase is open but the emergency lighting is out. The lift is right in front of you with its call button still glowing.\n\nMs. Okafor is leading the main group toward the blocked stairs, hoping to clear a path.",
			choices = {
				{ text = "Take the lift. It's fastest and the button is lit.", next = "lift", chance = { p = 0.35, win = "outside_safe", lose = "lift_stuck" }, note = "You press the button..." },
				{ text = "Use the dark back stairs.", next = "back_stairs", requires = { items = { "torch" } }, effects = { calm = 5 }, note = "Your torch beam cuts through the dark." },
				{ text = "Feel your way down the back stairs without light.", next = "back_stairs_dark" },
				{ text = "Stay with the teacher's group at the blocked stairs.", next = "aftershock" },
			},
		},

		lift_stuck = {
			fx = "dark",
			text = "The lift jolts, drops half a floor, and stops dead. The lights go out. You are trapped in a metal box between floors with no signal. An aftershock rattles the cables. It takes rescue crews six hours to get you out.",
			ending = { kind = "survived", title = "Stuck Between Floors" },
			lesson = "Never use lifts during or after an earthquake. Power failures and aftershocks can trap you, and cables can be damaged.",
		},

		back_stairs = {
			fx = "dark",
			text = "With the torch you spot a gap where the staircase has pulled away from the wall, and you step carefully around it. Halfway down you hear shouting from the blocked group above.",
			choices = {
				{ text = "Go back up and guide them to the back stairs.", next = "rescue_group", effects = { calm = -10 } },
				{ text = "Keep going. Get outside and tell the rescuers.", next = "outside_safe" },
			},
		},

		back_stairs_dark = {
			fx = "dark",
			text = "You grip the rail and take it one step at a time. On the third landing, your foot finds a gap where the stairs have shifted. You stumble and wrench your ankle, but catch the rail.",
			choices = {
				{ text = "Grit your teeth and keep going.", next = "outside_safe", hold = 2.5, effects = { health = -20 }, note = "Your ankle throbs, but you make it down." },
				{ text = "Sit and wait for help.", next = "aftershock" },
			},
		},

		aftershock = {
			fx = "quake",
			text = "Twenty minutes later, an aftershock hits. Plaster rains down in the corridor. The group at the blocked stairs scatters.",
			choices = {
				{ text = "Drop, cover, and hold on right where you are.", next = "outside_safe", hold = 4, effects = { calm = -5 } },
				{ text = "Run toward the back stairs.", next = "outside_safe", chance = { p = 0.5, win = "outside_safe", lose = "death", loseEffects = { health = -60 } }, note = "Running during shaking is risky..." },
			},
		},

		rescue_group = {
			fx = "calm",
			text = "You climb back up and shout through the gap. \"The back stairs are open! Use my torch, come this way!\" Fifteen students and Ms. Okafor file past you in the dark. One of them is the kid who was too scared to move.",
			choices = {
				{ text = "Lead them down and out to the football field.", next = "hero_ending" },
			},
		},

		hero_ending = {
			fx = "calm",
			text = "On the field, teachers take a head count. When your name is called, Ms. Okafor squeezes your shoulder. \"You made sure everyone got out.\"\n\nYour class gets a new meeting point and a new fire drill, and you are the one who explains it to the Year 7s.",
			ending = { kind = "hero", title = "The Class Remembers" },
			lesson = "Calm leadership saves lives. In an emergency, helping others get out safely is the best use of what you know.",
		},

		outside_safe = {
			fx = "calm",
			text = "You step out into the cold air of the field. Sirens are far off. Teachers are counting heads. Power lines hang from a pole near the gate, so everyone is waved away from them.\n\nYou are safe. Your hands do not stop shaking for a long time.",
			ending = { kind = "survived", title = "On the Field" },
			lesson = "After the shaking stops: check for injuries, leave via stairs, stay clear of damaged buildings and power lines, and expect aftershocks.",
		},

		death = {
			fx = "dark",
			text = "The ceiling, the crowd, or the next aftershock. In the end the building took more than you could handle. Your classmates will never forget this day.",
			ending = { kind = "died", title = "Did Not Make It" },
			lesson = "Most earthquake injuries come from falling objects and panic. Drop, cover, and hold on, and move slowly and calmly afterwards.",
		},
	},
}
]=====])

local _ = make("ModuleScript", "Subway", scenarios, [=====[
--!nocheck
-- Scenario: flash flood reaches an underground station.
return {
	id = "subway",
	title = "Rising Water",
	place = "Subway",
	disaster = "Flash Flood",
	icon = "🚇",
	difficulty = "Medium",
	blurb = "Marlow Street Station. A storm has been raining for hours, and the tunnel is filling up.",
	start = "start",
	deathNode = "death",
	lesson = "Floodwater is faster and stronger than it looks. Move up and away, never through it.",
	nodes = {
		start = {
			fx = "flood",
			text = "Evening rush hour. You are on the Line 4 platform at Marlow Street, soaked from the storm outside. The board flickers: SERVICE SUSPENDED.\n\nThen you notice the thin sheet of water spreading across the platform floor, and a roar from the staircase you came down. Brown water is pouring down the steps.",
			choices = {
				{ text = "Run up the stairs, against the water.", next = "stairs", effects = { calm = -10 } },
				{ text = "Press the emergency intercom and call for help.", next = "intercom", effects = { calm = 5 }, note = "A tired voice answers: \"Station control.\"" },
				{ text = "Walk toward the far end of the platform.", next = "far_end" },
				{ text = "Climb onto the stalled train for a better view.", next = "train_roof", effects = { calm = -5, give = { "phone light" } } },
			},
		},

		stairs = {
			fx = "flood",
			text = "Halfway up, the water hits your knees and shoves you backward. A man grabs the rail beside you and shouts that the street is flooded too. It is knee-deep and brown, and it is full of debris.\n\nYou slip. The current drags your legs out from under you.",
			choices = {
				{ text = "Grab the handrail with both hands and hang on.", next = "stairs_hold", hold = 5, chance = { p = 0.6, win = "stairs_hold", lose = "washed_back", loseEffects = { health = -30 } }, note = "Your grip is slipping..." },
				{ text = "Let go and swim for the platform.", next = "washed_back", effects = { health = -30 } },
			},
		},

		stairs_hold = {
			fx = "flood",
			text = "You hold on. The man from the stairs hauls you up by your jacket and together you cling to the rail until the surge passes. But the street exit is under a meter of water. You cannot go out that way.",
			choices = {
				{ text = "Go back down and use the intercom.", next = "intercom", effects = { health = -10, calm = -10 } },
				{ text = "Head for the far end of the platform.", next = "far_end", effects = { health = -10 } },
			},
		},

		washed_back = {
			fx = "flood",
			text = "The water carries you back down the stairs and dumps you on the platform. You cough and gasp. Water is now ankle-deep and rising fast. A stranger hauls you to your feet. \"The ladder to the maintenance shaft!\" she shouts, pointing down the platform.",
			choices = {
				{ text = "Follow her to the far end.", next = "far_end", effects = { calm = -5 } },
			},
		},

		intercom = {
			fx = "flood",
			text = "\"Station control. Marlow Street is flooding. We are evacuating via Exit C at the far end. Do NOT use the tracks. The rails are live until we cut power.\"\n\nThe voice cuts out. Water laps at the platform edge. Behind you, an elderly man with a cane is struggling to stay upright against the flow.",
			choices = {
				{ text = "Help the elderly man walk toward Exit C.", next = "far_end", effects = { calm = 5, set = { "helped_stranger" } }, note = "He leans on your arm. \"Thank you, kid.\"" },
				{ text = "Head to Exit C alone. You cannot carry everyone.", next = "far_end", effects = { calm = -10 } },
				{ text = "Jump down to the tracks and run through the tunnel.", next = "tunnel", effects = { calm = -10 } },
			},
		},

		tunnel = {
			fx = "dark",
			text = "You drop onto the tracks. It is pitch black and the water is already at your shins. You feel the metal of the rail brush your foot. Is power still on?\n\nA flicker of sparks lights the tunnel. The third rail is half-submerged ahead of you.",
			choices = {
				{ text = "Climb back to the platform. Do not touch the rails.", next = "far_end", effects = { health = -15, calm = -15 }, note = "You scramble up, heart pounding." },
				{ text = "Wade past the rail, hugging the wall.", next = "death", effects = { health = -100 }, note = "The water carries the current." },
			},
		},

		train_roof = {
			fx = "flood",
			text = "You pull yourself up onto the roof of the train. From here you can see the whole platform: the water has swallowed the benches and is already above the first rung of the maintenance ladder at the far end. Others on the platform are screaming for help.\n\nThe water keeps rising. The roof of the train will not stay above it for long.",
			choices = {
				{ text = "Jump back down and run for the ladder at the far end.", next = "far_end", effects = { calm = -5 } },
				{ text = "Stay on the roof and wait for rescue.", next = "wait_roof" },
			},
		},

		wait_roof = {
			fx = "flood",
			text = "Twenty minutes pass. The water climbs until it laps at the underside of the train carriage. The roof begins to shake as the current rocks the train. Your teeth are chattering.",
			choices = {
				{ text = "Shout for help and wave your phone light.", next = "boat_rescue", requires = { items = { "phone light" } } },
				{ text = "Jump down and swim for the ladder.", next = "far_end", effects = { health = -25, calm = -10 }, note = "The water is freezing and fast." },
			},
		},

		boat_rescue = {
			fx = "calm",
			text = "A rescue boat finds you at last. You wait on the roof as the rescuers pull people up one by one. When the boat reaches the ladder, you climb in. It is only when you are out in the open air that you realise how dangerous that tunnel was.",
			ending = { kind = "survived", title = "Rescued by Boat" },
			lesson = "If you cannot get out, go to the highest dry point and signal clearly for help. Do not try to move through fast-moving water.",
		},

		far_end = {
			fx = "flood",
			text = "At the far end of the platform, a steel door marked EXIT C hangs open. Beyond it a metal ladder climbs into a dark maintenance shaft. Water is up to your thighs and surging.\n\nA small group is already there. A girl with a toddler cannot reach the first rung.",
			choices = {
				{ text = "Lift the toddler onto the ladder first.", next = "shaft", effects = { calm = 5, health = -10, set = { "helped_child" } }, note = "The mother sobs thanks as you boost her kid up." },
				{ text = "Push to the front. You need to get out now.", next = "shaft", effects = { calm = -15 }, note = "Others shout at you, but you are up the ladder." },
				{ text = "Cut a strap from a bag with your knife for a rope.", next = "shaft", requires = { items = { "knife" } }, hiddenIfLocked = true, effects = { give = { "belt" }, calm = 5 } },
				{ text = "Look for something to use as a rope.", next = "shaft", effects = { give = { "belt" } }, note = "You pull a strap from a bag." },
			},
		},

		shaft = {
			fx = "dark",
			text = "The ladder climbs for what feels like forever. Halfway up, the one above you freezes. The rung is rusted through and swinging loose. The water is rising right behind you.",
			choices = {
				{ text = "Swing across to the next ladder and pull yourself up.", next = "hatch", hold = 3, chance = { p = 0.55, win = "hatch", lose = "hatch", loseEffects = { health = -25 }, winNote = "You catch the rung and haul yourself up.", loseNote = "You slip and crash into the rungs, scraping both arms." } },
				{ text = "Use the belt to bind the broken rung.", next = "hatch", requires = { items = { "belt" } }, note = "It holds, barely." },
				{ text = "Keep climbing on the damaged ladder.", next = "death", effects = { health = -100 }, note = "The rung gives way." },
			},
		},

		hatch = {
			fx = "dark",
			text = "At the top of the shaft is a heavy steel hatch, held shut by the pressure of the rain on the other side. Below you, water is rising. The people on the ladder are shoving against you.",
			choices = {
				{ text = "Push the hatch with your shoulder and shout for the others to help.", next = "street", chance = { p = 0.6, win = "street", lose = "street", loseEffects = { health = -15 }, boostItem = "belt", boost = 0.1 } },
			},
		},

		street = {
			fx = "calm",
			text = "The hatch bursts open and cold air and rain hit your face. You climb out onto a raised sidewalk. The street below is a river. Firefighters in orange suits are wading toward you with ropes.",
			choices = {
				{ text = "Help pull up the next person from the shaft.", next = "hero_ending", requires = { flags = { "helped_child" } }, hiddenIfLocked = true },
				{ text = "Look around for who is still down there.", next = "hero_ending", requires = { flags = { "helped_stranger" } }, hiddenIfLocked = true },
				{ text = "Collapse on the sidewalk and let the firefighters take over.", next = "street_ending" },
			},
		},

		hero_ending = {
			fx = "calm",
			text = "You lean back into the shaft and haul up the next person, then the next. By the time the firefighters reach you, nine people have climbed out of Exit C because you refused to leave them behind.\n\nThe news calls it a miracle. You call it a team effort.",
			ending = { kind = "hero", title = "Nine Out of Exit C" },
			lesson = "When it is safe, helping others during an evacuation saves more lives. Just never put yourself in the flood's path to do it.",
		},

		street_ending = {
			fx = "calm",
			text = "A firefighter drapes a blanket around your shoulders. You sit on the curb, soaked and shaking, watching the water pour into the station you left behind. You made it, and you will take the bus from now on.",
			ending = { kind = "survived", title = "Above the Waterline" },
			lesson = "Even six inches of moving water can knock you off your feet. Two feet can float a car. Turn around, do not drown.",
		},

		death = {
			fx = "dark",
			text = "The water, the dark, and the current were stronger than you. The underground station fills silently. It is one of the worst nights the city has ever had.",
			ending = { kind = "died", title = "Swept Under" },
			lesson = "Never enter floodwater or train tunnels. Floodwater hides debris and live electricity, and cannot be outswum.",
		},
	},
}
]=====])

local _ = make("ModuleScript", "Wildfire", scenarios, [=====[
--!nocheck
-- Scenario: wildfire reaches a lakeside campsite.
return {
	id = "wildfire",
	title = "Ember Night",
	place = "Campsite",
	disaster = "Wildfire",
	icon = "🔥",
	difficulty = "Hard",
	blurb = "Pine Lake Campground. Dry winds, an orange glow on the ridge, and one road out.",
	start = "start",
	deathNode = "death",
	lesson = "Wildfires move faster than you can run. Leave early, and choose a route away from fuel.",
	nodes = {
		start = {
			fx = "fire",
			text = "Day three of the camping trip. You, your friends Dani and Leo, and your older cousin Remy are playing cards when you notice the smell: smoke, thick and sharp. The sky to the west has turned a dirty orange.\n\nA ranger truck rolls through the campground with a loudspeaker: \"Evacuation order. Leave now by the south road.\"",
			choices = {
				{ text = "Leave right now. Grab the car keys and go.", next = "road", effects = { calm = -5 } },
				{ text = "Pack the tents and gear first, then go.", next = "packing", effects = { calm = -5 } },
				{ text = "Check the fire first. Climb the ridge for a view.", next = "ridge", effects = { calm = -5 } },
			},
		},

		packing = {
			fx = "fire",
			text = "Packing a tent takes longer than you think. Ten minutes later, the wind shifts and embers begin to fall around the campsite. Remy is shouting from the car. Dani is trying to roll up a sleeping bag with shaking hands.",
			choices = {
				{ text = "Drop everything and get in the car.", next = "road", effects = { calm = -10, health = -5 }, note = "You leave the tents burning behind you." },
				{ text = "Keep packing. It is expensive gear.", next = "trapped_camp", effects = { calm = -15 } },
			},
		},

		ridge = {
			fx = "fire",
			text = "From the ridge, you see it: a wall of fire racing across the hillside toward the campground and the road. It is moving far faster than you expected, and the wind is pushing it straight at you. You can hear it, like a freight train.\n\nYou run back to camp. Everyone is staring at you.",
			choices = {
				{ text = "Yell: \"Car, now! The road is the only way!\"", next = "road", effects = { calm = -15, health = -10 } },
				{ text = "Shout: \"Fire's too close, head for the lake!\"", next = "lake", effects = { calm = -10 } },
			},
		},

		road = {
			fx = "fire",
			text = "You pile into Remy's car. The south road is a single lane of gravel through the pines. Within a mile, you hit a line of brake lights. A truck has broken down ahead, and smoke is rolling across the road. Behind you, flames are leaping from tree to tree.",
			choices = {
				{ text = "Stay in the car, close the vents, and wait it out.", next = "car_wait", effects = { calm = -10 } },
				{ text = "Abandon the car and run back to the lake.", next = "lake", effects = { health = -15, calm = -15 } },
				{ text = "Help the stalled driver push the truck off the road.", next = "push_truck", effects = { calm = -5 } },
			},
		},

		push_truck = {
			fx = "fire",
			text = "You and Leo run to the truck. Together with three other people, you shove it into the ditch, bumper first. The line of cars lurches forward. Smoke stings your eyes and the heat is intense, but the road is clear.",
			choices = {
				{ text = "Jump back in and race out with the convoy.", next = "convoy", effects = { health = -10, set = { "cleared_road" } } },
			},
		},

		convoy = {
			fx = "fire",
			text = "The convoy crawls through the smoke, tail lights in front of you glowing like embers. The air inside the car is hot. Then the trees thin out and you reach an open meadow, and a fire crew with water trucks waving cars through.",
			ending = { kind = "hero", title = "Cleared the Road" },
			lesson = "Evacuating early by the designated route, and helping clear the way, can save a whole convoy. Always follow official evacuation orders.",
		},

		car_wait = {
			fx = "fire",
			text = "Heat shimmers on the windscreen. You can hear the fire crackling closer. Someone shouts that you have to get out of the cars. Then the front-most car's tyre bursts from the heat.",
			choices = {
				{ text = "Run for the lake on the far side of the field.", next = "lake", effects = { health = -20, calm = -10 } },
				{ text = "Stay put. The car is a metal box.", next = "death", effects = { health = -100 }, note = "The cars cannot withstand the fire front." },
			},
		},

		trapped_camp = {
			fx = "fire",
			text = "Ten more minutes and the wind shifts for the worst. A fireball roars into the campground. You flee on foot with nothing, and the car is blocked by burning trees.\n\nYou see the lake, a hundred metres away, glittering orange. It is your last chance.",
			choices = {
				{ text = "Sprint for the lake.", next = "lake", effects = { health = -35, calm = -20 } },
			},
		},

		lake = {
			fx = "fire",
			text = "The lake is cool and black and calm. You wade in up to your neck. Behind you the campsite is a wall of flame. Heat scorches your back, and the air is thick with smoke. A bandana and a water bottle would be good right now.",
			choices = {
				{ text = "Soak your shirt with your water bottle first, then wade in.", next = "lake_night", requires = { items = { "water" } }, hiddenIfLocked = true, effects = { give = { "wet cloth" }, calm = 10, health = 10 } },
				{ text = "Wet your shirt and breathe through it.", next = "lake_night", effects = { give = { "wet cloth" }, calm = 5 } },
				{ text = "Duck under whenever the heat surges.", next = "lake_night", effects = { calm = -5, health = -5 } },
				{ text = "Swim across to the far shore, away from the fire.", next = "far_shore", effects = { calm = -10 } },
			},
		},

		far_shore = {
			fx = "fire",
			text = "The swim is long, and the cold bites hard. On the far shore, a pebble beach with no trees nearby, a family has already gathered, huddled in towels. A little boy is crying, and a woman waves at you.",
			choices = {
				{ text = "Help the family into the water and keep them calm.", next = "lake_night", effects = { calm = -5, health = -10, set = { "helped_family" } } },
				{ text = "Collapse on the sand and rest.", next = "lake_night", effects = { calm = 10 } },
			},
		},

		lake_night = {
			fx = "fire",
			text = "The hours pass. The fire front sweeps by, leaving black skeletons of trees. Burning branches fall into the lake with a hiss. The air stays thick with smoke, but the water protects you.\n\nAt first light you hear a chopper.",
			choices = {
				{ text = "Wave your wet shirt, spread wide on the sand.", next = "helicopter", requires = { items = { "wet cloth" } } },
				{ text = "Wave your arms and shout.", next = "helicopter", chance = { p = 0.7, win = "helicopter", lose = "late_rescue" } },
			},
		},

		helicopter = {
			fx = "calm",
			text = "The helicopter circles, then drops a line. Crews haul out each survivor on the beach and fly you to a safe zone. At the evacuation centre, you find Dani, Leo and Remy, all of them safe. All the gear is gone, but you do not care.",
			ending = { kind = "survived", title = "Lifted from the Lake" },
			lesson = "Bodies of water and bare ground can protect you when the fire front passes. Stay low, cover your face, and signal clearly for rescue.",
		},

		late_rescue = {
			fx = "calm",
			text = "The chopper does not see you. You wait through the smoke-filled day, shivering in the water, until a ground crew finds you at dusk. You will have lung problems for months, but you are alive.",
			ending = { kind = "survived", title = "Long Wait" },
			lesson = "A bright, visible signal helps rescuers find you quickly. Do not rely on being noticed.",
		},

		death = {
			fx = "dark",
			text = "The fire moved faster than anyone could believe. Smoke, heat and panic closed every door. The park will rebuild, but you will not forget this night.",
			ending = { kind = "died", title = "Lost to the Fire" },
			lesson = "Most wildfire deaths happen when people delay leaving. Leave as soon as an evacuation order is issued.",
		},
	},
}
]=====])

local _ = make("ModuleScript", "Tsunami", scenarios, [=====[
--!nocheck
-- Scenario: strong coastal earthquake followed by a tsunami.
return {
	id = "tsunami",
	title = "The Sea Pulls Back",
	place = "Beach Resort",
	disaster = "Tsunami",
	icon = "🌊",
	difficulty = "Medium",
	blurb = "Sunny morning on the beach. The ground shakes for a full minute, and then the ocean disappears.",
	start = "start",
	deathNode = "death",
	lesson = "Strong shaking near the coast, or the sea suddenly draining away, is the warning. Do not wait for a siren.",
	nodes = {
		start = {
			fx = "calm",
			text = "You are on a sunbed outside the Palm Bay Resort with your little sister Mia, sipping a fruit drink, when the ground begins to roll. A glass shatters. Palm trees sway. The shaking lasts almost a full minute.\n\nWhen it stops, people laugh nervously and start filming. Mia grins: \"That was cool!\"",
			choices = {
				{ text = "Grab Mia and head inland, uphill. Now.", next = "inland", effects = { calm = -5, set = { "has_mia" } } },
				{ text = "Ask a lifeguard what is going on.", next = "lifeguard" },
				{ text = "Stay and wait for an official announcement.", next = "wait" },
			},
		},

		wait = {
			fx = "calm",
			text = "Five minutes pass. No sirens. Phones have no signal. A boy near you points at the water: \"Look! The sea is going out!\" Fish are flopping on the exposed sand, and the water has retreated hundreds of metres.\n\nPeople are walking out onto the wet seabed to take photos.",
			choices = {
				{ text = "Run. This is the warning sign.", next = "inland", effects = { calm = -15, set = { "has_mia" } }, note = "You grab Mia's hand and sprint." },
				{ text = "Walk out onto the seabed to see for yourself.", next = "seabed", effects = { calm = -5 } },
			},
		},

		lifeguard = {
			fx = "calm",
			text = "The lifeguard is already on the radio. \"Strong quake. Possible tsunami. Everyone to high ground, up the hill past the road or to the upper floors of the hotel. Go now. Do not wait for the siren.\"",
			choices = {
				{ text = "Grab Mia and run up the hill road.", next = "inland", effects = { calm = -5, set = { "has_mia" } } },
				{ text = "Take Mia into the hotel and go up the stairs.", next = "hotel", effects = { calm = -5, set = { "has_mia" } } },
				{ text = "Run back to your room to grab your passport and phone.", next = "room", effects = { calm = -10 } },
			},
		},

		room = {
			fx = "calm",
			text = "You race to your ground-floor room. The door is jammed from the quake and you waste minutes forcing it open. When you finally get out with your bag, the beach is deserted except for one thing: far out where the sea used to be, a long white line is rising on the horizon.",
			choices = {
				{ text = "Drop the bag and run for the hotel stairs.", next = "hotel", effects = { calm = -20, health = -10 } },
				{ text = "Run uphill. The road is closer to you than the hotel.", next = "inland", effects = { calm = -20, health = -10 } },
			},
		},

		seabed = {
			fx = "wave",
			text = "The sand is hard and wet and littered with stranded fish. You are fifty metres out when you hear screaming behind you. You turn around. A wall of water is racing across the bay, filled with boats, trees, and the remains of the pier.",
			choices = {
				{ text = "Run for the hotel as fast as you can.", next = "death", chance = { p = 0.1, win = "hotel", lose = "death" }, note = "It is too far..." },
			},
		},

		inland = {
			fx = "wave",
			text = "The coastal road is already jammed with cars. Horns, shouting, a motorbike on the pavement. Mia is panting but keeps up. The hill is a few hundred metres ahead. You can hear a deep roar from the beach, like a river.",
			choices = {
				{ text = "Leave the road and take the steep footpath uphill.", next = "footpath", effects = { health = -10, calm = -5 } },
				{ text = "Hop into a stranger's car crawling in traffic.", next = "car_trap", effects = { calm = -5 } },
				{ text = "Carry Mia on your back and sprint for the hotel instead.", next = "hotel", requires = { flags = { "has_mia" } }, effects = { health = -10, calm = -10 } },
			},
		},

		car_trap = {
			fx = "wave",
			text = "The car does not move. Traffic is solid. Behind you, the sea is a grey wall rushing through the streets. The driver is frozen.",
			choices = {
				{ text = "Jump out, grab Mia, and scramble up the embankment.", next = "footpath", chance = { p = 0.5, win = "footpath", lose = "death", loseEffects = { health = -60 } }, effects = { calm = -15 } },
			},
		},

		footpath = {
			fx = "wave",
			text = "The path is muddy and steep. Mia's sandals slide. You boost her up by the arms while a local man reaches down from above. The roar rises behind you. Water surges up the lower slope, swallowing the road and the car park.",
			choices = {
				{ text = "Keep climbing. Higher, higher.", next = "hilltop", hold = 3, effects = { health = -5 } },
				{ text = "Stop and look back to see how bad it is.", next = "hilltop_late", effects = { calm = -10 } },
			},
		},

		hilltop_late = {
			fx = "wave",
			text = "You look back and see the resort vanish into brown water. The hotel's ground floor is gone. A second wave rolls in, higher than the first, and its spray soaks you. The local man drags you up the slope by the shoulder.",
			choices = {
				{ text = "Scramble up the slope.", next = "hilltop", effects = { health = -15 } },
			},
		},

		hotel = {
			fx = "wave",
			text = "The Palm Bay is a concrete building, eight storeys tall. The stairwell is packed. On the third floor, an elderly woman has sat down on the landing, unable to climb further.",
			choices = {
				{ text = "Help her up the stairs, one step at a time.", next = "roof", effects = { health = -10, calm = -5, set = { "helped_woman" } } },
				{ text = "Keep climbing. The wave is coming.", next = "roof", effects = { calm = -10 } },
				{ text = "Eat your snack bar for energy and carry her up.", next = "roof", requires = { items = { "food" } }, hiddenIfLocked = true, effects = { calm = 5, set = { "helped_woman" } } },
				{ text = "Stop at the third floor. That is high enough.", next = "death", effects = { health = -100 }, note = "The wave tops three storeys." },
			},
		},

		roof = {
			fx = "wave",
			text = "On the roof of the resort, dozens of people are huddled together. Below, the wave crashes into the lower floors with a thunderous boom and the whole building shudders. Water surges through the lobby. The sea keeps rising for what feels like forever, then begins to drain.\n\nYou hold Mia tight and do not look down.",
			choices = {
				{ text = "Hold Mia tight and wait for rescue. More waves could come.", next = "roof_ending" },
			},
		},

		roof_ending = {
			fx = "calm",
			text = "Waves come in for hours. Rescue helicopters pick up survivors from the roof the next morning. The elderly woman, if you helped her, holds your hand tight on the flight out. Mia is quiet. Then she says: \"We should have listened to the ground.\"\n\nShe is right.",
			ending = { kind = "survived", title = "Vertical Evacuation" },
			lesson = "If you cannot reach high ground, go to the upper floors of a strong concrete building (at least 4 storeys up). Tsunamis come in several waves, so stay put until officials say it is safe.",
		},

		hilltop = {
			fx = "calm",
			text = "You reach the top of the hill, where dozens of survivors stand looking down at the bay. The resort is gone. The sea is brown and full of wreckage. Mia clings to your side.\n\nA man near you is searching the crowd and shouting a name over and over.",
			choices = {
				{ text = "Help organise the group and share your phone's signal.", next = "hero_ending", requires = { flags = { "has_mia" } }, hiddenIfLocked = true },
				{ text = "Sit with Mia and wait for news.", next = "hilltop_ending" },
			},
		},

		hero_ending = {
			fx = "calm",
			text = "You and a few others set up a list of names on the back of a map. Phones come back on one by one. By evening, you have reconnected eleven families. Mia hands out water bottles to the children.\n\nThe local news interviews you at the evacuation centre. \"I just ran,\" you say. \"And I made sure she ran too.\"",
			ending = { kind = "hero", title = "Higher Ground, Together" },
			lesson = "Acting on natural warning signs, rather than waiting for official alerts, gives you and the people around you the best chance.",
		},

		hilltop_ending = {
			fx = "calm",
			text = "You sit with Mia, wrapped in a stranger's blanket, until the sun goes down. Rescue crews arrive. You are alive, and so is she. The beach is gone, but you have each other.",
			ending = { kind = "survived", title = "Above the Wave" },
			lesson = "Move inland and uphill as soon as you feel a strong earthquake. A tsunami can reach shore in minutes.",
		},

		death = {
			fx = "dark",
			text = "The wave came faster than anyone could believe. By the time you understood the signs, it was too late. Palm Bay will be remembered as a place where the warning came from the earth itself.",
			ending = { kind = "died", title = "Swept Away" },
			lesson = "A receding sea is a tsunami warning. Never go to look at it. Run uphill.",
		},
	},
}
]=====])

local _ = make("ModuleScript", "Zombies", scenarios, [=====[
--!nocheck
-- Scenario: zombie outbreak in an apartment block.
return {
	id = "zombies",
	title = "Dead Hours",
	place = "Apartment Block",
	disaster = "Zombie Outbreak",
	icon = "🧟",
	difficulty = "Hard",
	blurb = "Day one of the outbreak. Third floor, one locked door, and something is pounding on it.",
	start = "start",
	deathNode = "death",
	lesson = "In any crisis: stay quiet, secure your space, gather food and water, and move only with a plan.",
	nodes = {
		start = {
			fx = "dark",
			text = "You wake to screaming. Not from the TV, from the corridor. Through the wall you hear glass breaking, a door slamming, and a wet, wrong sound you cannot place. Your phone shows forty missed alerts: ATTACKS REPORTED. STAY INDOORS. DO NOT APPROACH THE INFECTED.\n\nSomeone is thumping on your front door, slowly, over and over.",
			choices = {
				{ text = "Look through the peephole.", next = "peep", effects = { calm = -5 } },
				{ text = "Shove the sofa against the door.", next = "barricade", effects = { calm = 5 } },
				{ text = "Grab your bag and run for the stairwell.", next = "stairs", effects = { calm = -15 } },
			},
		},

		peep = {
			fx = "dark",
			text = "It is Mrs. Alvarez from 3C, the neighbour who feeds the cat. Her eyes are grey and her mouth is dark with blood. She does not blink. She keeps hitting the door with an open hand.",
			choices = {
				{ text = "Open it. Maybe she just needs help.", next = "barricade", chance = { p = 0.15, win = "barricade", lose = "barricade", loseEffects = { health = -45, calm = -20 }, winNote = "She stumbles past you into the stairwell. You slam the door.", loseNote = "She lunges and bites your forearm before you can shut the door." } },
				{ text = "Stay silent and back away.", next = "barricade", effects = { calm = -5 } },
				{ text = "Call your mum on the phone.", next = "phone" },
			},
		},

		phone = {
			fx = "dark",
			text = "Your mum picks up on the first ring. \"Listen. The radio says boats leave from Harbor Pier at dawn, and helicopters are taking people off the roof of Hartley Tower. I am at your aunt's. Do NOT come here. Get to one of them. Please.\"\n\nThe line cuts out.",
			choices = {
				{ text = "Write both places down and push the sofa against the door.", next = "barricade", effects = { calm = 5 } },
			},
		},

		barricade = {
			fx = "dark",
			text = "The sofa, the table and the bookcase make a decent wall. Whatever is outside keeps pounding, then slowly loses interest and shuffles off. It is quiet. Too quiet.\n\nYour stomach growls. You have maybe three days of food in the flat. Outside the window, smoke rises over the city.",
			choices = {
				{ text = "Search the kitchen for anything useful.", next = "plan", effects = { give = { "pan" }, calm = 5 }, note = "You find a heavy cast-iron pan." },
				{ text = "Check the fire escape outside the bedroom window.", next = "fire_escape" },
				{ text = "Raid the fridge and cupboards, then hunker down and wait for rescue.", next = "siege", effects = { give = { "food" }, calm = -5 } },
				{ text = "Hunker down with what you have and wait for rescue.", next = "siege", effects = { calm = -5 } },
			},
		},

		siege = {
			fx = "dark",
			text = "Day three. The pounding has stopped, but now it is the silence that hurts. Your food is nearly gone and the tap runs brown. Somewhere far off, an engine rumbles, a military convoy, you think. It is passing by your street.",
			choices = {
				{ text = "Ration your food and wait one more day.", next = "safe_ending", requires = { items = { "food" } }, hiddenIfLocked = true, effects = { calm = 10 } },
				{ text = "Go out now and flag the convoy down.", next = "stairs", effects = { health = -10, calm = -10 } },
				{ text = "Keep waiting. They will come.", next = "death", effects = { health = -100 }, note = "No one comes in time." },
			},
		},

		safe_ending = {
			fx = "calm",
			text = "You sip the last water and wait. On the fourth day, soldiers go door to door with loudhailers, clearing each building. They knock on your barricade and call out: \"Anyone alive in there? We are evacuating survivors.\"\n\nYou answer, your voice cracking.",
			ending = { kind = "survived", title = "The Long Siege" },
			lesson = "Sheltering in place only works if you have supplies. Food, water and a plan make waiting survivable.",
		},

		plan = {
			fx = "dark",
			text = "While searching, your portable radio crackles. \"...Harbor Pier. Boats at dawn. Helicopters from Hartley Tower roof, last flight at noon. All other routes are unsafe...\" You have to pick one.",
			choices = {
				{ text = "Head for Harbor Pier.", next = "stairs", effects = { set = { "goal_harbor" } } },
				{ text = "Head for Hartley Tower.", next = "stairs", effects = { set = { "goal_tower" } } },
			},
		},

		stairs = {
			fx = "dark",
			text = "The stairwell is dark. A body in a hoodie lies slumped on the landing. It lifts its head. Further down, two more shapes shuffle toward you, drawn by the noise.\n\nThere is no other way down.",
			choices = {
				{ text = "Fight through with your knife.", next = "street", requires = { items = { "knife" } }, hiddenIfLocked = true, effects = { health = -10, calm = 5 }, note = "You are fast and decisive, and the stairs are clear." },
				{ text = "Swing the pan at the first one.", next = "street", requires = { items = { "pan" } }, hiddenIfLocked = true, chance = { p = 0.5, win = "street", lose = "street", loseEffects = { health = -35, calm = -15 }, winNote = "The pan connects with a clang and you push through.", loseNote = "One of them grabs your arm and tears your sleeve before you break free." } },
				{ text = "Sneak past them, one step at a time.", next = "street", chance = { p = 0.4, win = "street", lose = "street", loseEffects = { health = -30, calm = -20 }, winNote = "They shuffle right past without noticing you.", loseNote = "A step creaks. You sprint down with them on your heels." } },
			},
		},

		fire_escape = {
			fx = "dark",
			text = "The iron fire escape clangs in the wind. Below, an alley full of dumpsters and wandering shapes. Above, a ladder leads to the roof of the building. Someone up there is waving a torch.",
			choices = {
				{ text = "Climb down into the alley.", next = "alley", effects = { health = -5, calm = -10 }, chance = { p = 0.6, win = "alley", lose = "alley", loseEffects = { health = -25 }, loseNote = "A rung gives way and you tumble the last few metres." } },
				{ text = "Climb up to the roof.", next = "roof", effects = { calm = 5 } },
			},
		},

		street = {
			fx = "dark",
			text = "The lobby doors burst open onto an empty street. Cars are abandoned with their doors hanging open. A figure drags itself across the road. A car sits with its keys still in the ignition, engine ticking.",
			choices = {
				{ text = "Try the car. It is the fastest way across the city.", next = "alley", chance = { p = 0.5, win = "alley", lose = "alley", loseEffects = { health = -20, calm = -15 }, winNote = "The engine catches and you roar away.", loseNote = "It stalls. You bolt on foot as the shapes close in." } },
				{ text = "Slip into the back alleys on foot.", next = "alley", effects = { calm = -5 } },
			},
		},

		alley = {
			fx = "dark",
			text = "The alley opens onto the main road. Straight ahead the city is a maze of burning cars and wandering silhouettes. You can see your goal in the distance. It is a long way.",
			choices = {
				{ text = "Eat your food, then sprint the whole way to the Pier.", next = "pier", requires = { items = { "food" }, notFlags = { "goal_tower" } }, hiddenIfLocked = true, effects = { calm = 5 } },
				{ text = "Dash between wrecked cars toward the Pier.", next = "pier", chance = { p = 0.55, win = "pier", lose = "death", loseEffects = { health = -70 } }, requires = { notFlags = { "goal_tower" } }, hiddenIfLocked = true },
				{ text = "Eat your food, then sprint the whole way to Hartley Tower.", next = "tower", requires = { items = { "food" }, flags = { "goal_tower" } }, hiddenIfLocked = true, effects = { calm = 5 } },
				{ text = "Dash between wrecked cars toward Hartley Tower.", next = "tower", chance = { p = 0.55, win = "tower", lose = "death", loseEffects = { health = -70 } }, requires = { flags = { "goal_tower" } }, hiddenIfLocked = true },
			},
		},

		pier = {
			fx = "calm",
			text = "Harbor Pier is a wall of floodlights and rifles. Soldiers hold back the infected at a barricade while boats take on passengers one by one. A family with two small children is stuck at the back of the line, pushed aside by the crowd.",
			choices = {
				{ text = "Help the family reach the front of the line.", next = "hero_pier", effects = { health = -10, calm = -5 } },
				{ text = "Get on the boat. You earned your place.", next = "boat_ending" },
			},
		},

		hero_pier = {
			fx = "calm",
			text = "You shout to the soldier at the gangway and wave the family forward. For a moment it looks like the barricade will break. Then the children are lifted aboard, and you follow. As the boat pulls away, the little girl hands you her stuffed rabbit.",
			ending = { kind = "hero", title = "The Last Boat" },
			lesson = "Teamwork and compassion keep communities alive after a collapse. Survivors who cooperate do better than those who go alone.",
		},

		boat_ending = {
			fx = "calm",
			text = "You squeeze onto the deck as the engines roar. Behind you, the city burns. A medic hands you a blanket and a bottle of water, and for the first time in two days you let yourself breathe.",
			ending = { kind = "survived", title = "Off the Pier" },
			lesson = "Evacuating early to a planned location, with supplies, is the best way out of any large-scale emergency.",
		},

		tower = {
			fx = "dark",
			text = "Hartley Tower's lobby is dark and the lifts are dead. The sign on the wall reads ROOF ACCESS - FLOOR 22. You take the emergency stairs, floor by floor, listening for movement above and below. Your legs burn.",
			choices = {
				{ text = "Keep climbing, one landing at a time.", next = "roof", effects = { calm = -10, health = -5 } },
			},
		},

		roof = {
			fx = "calm",
			text = "On the roof, a handful of survivors huddle around a flare. A man is lying injured by the air vent and his teenage son Theo is holding his hand. A distant thudding grows louder. A helicopter, circling in the dark.",
			choices = {
				{ text = "Signal the helicopter with a bright flare.", next = "heli", chance = { p = 0.65, win = "heli", lose = "heli", loseEffects = { calm = -15 }, winNote = "The pilot sees you at once.", loseNote = "It circles twice before it notices you." } },
				{ text = "Share your food with Theo and his dad first.", next = "heli", requires = { items = { "food" } }, hiddenIfLocked = true, effects = { calm = 10, take = { "food" }, set = { "helped_theo" } }, note = "Theo manages a smile." },
			},
		},

		heli = {
			fx = "calm",
			text = "The helicopter drops a rope ladder. There is only room for a few. Theo's dad cannot climb alone.",
			choices = {
				{ text = "Carry Theo's dad up the ladder.", next = "hero_roof", effects = { health = -15, calm = -10 } },
				{ text = "Climb up yourself while you can.", next = "heli_ending" },
			},
		},

		hero_roof = {
			fx = "calm",
			text = "You strap Theo's dad to your back and climb, step by step, with the rotor wash tearing at your clothes. When you pull him inside, Theo hugs you so hard you can barely breathe. \"I do not know your name,\" he says. \"But I will never forget it.\"",
			ending = { kind = "hero", title = "Rooftop Rescue" },
			lesson = "Putting others first is not just noble, it builds the trust and bonds that get people through disasters.",
		},

		heli_ending = {
			fx = "calm",
			text = "You are hauled up into the helicopter and strapped in. The roof falls away beneath you and the city stretches out like a map of fire. You are alive. You try not to look back.",
			ending = { kind = "survived", title = "Airlifted Out" },
			lesson = "Make yourself visible and wait for official rescue. Never rely only on being noticed.",
		},

		death = {
			fx = "dark",
			text = "The city falls silent. In the end it was the crowd, the dark, and the bite you could not stop. Maybe someone on the next block will hold out a little longer.",
			ending = { kind = "died", title = "Overrun" },
			lesson = "Panic and rushing are the biggest killers in any crisis. Stay calm, move deliberately, and keep supplies ready.",
		},
	},
}
]=====])

local _ = make("ModuleScript", "Nuclear", scenarios, [=====[
--!nocheck
-- Scenario: missile alert, based on public civil-defence guidance
-- (get inside, stay inside, stay tuned).
return {
	id = "nuclear",
	title = "Flash Warning",
	place = "Office Tower",
	disaster = "Nuclear Missile",
	icon = "☢️",
	difficulty = "Hard",
	blurb = "Every phone in the office screams at once: missile inbound. You have minutes.",
	start = "start",
	deathNode = "death",
	lesson = "Official guidance after a nuclear alert: Get Inside, Stay Inside, Stay Tuned.",
	nodes = {
		start = {
			fx = "calm",
			text = "Tuesday, 10:14 a.m. Your office floor is full of keyboards clicking until every phone in the building shrieks at the same moment. The screen reads: BALLISTIC MISSILE THREAT INBOUND. SEEK IMMEDIATE SHELTER. THIS IS NOT A DRILL.\n\nPeople freeze, then split. Someone is shouting that it is a mistake. Someone else is already running for the doors.",
			choices = {
				{ text = "Check the news first. It might be a false alarm.", next = "doubt", effects = { calm = -5 } },
				{ text = "Head to the lower floors and basement right now.", next = "shelter_choice", effects = { calm = -5 } },
				{ text = "Run to your car. You need to get home to your family.", next = "car", effects = { calm = -10 } },
				{ text = "Go to the window to look for the missile.", next = "window", effects = { calm = -5 } },
			},
		},

		doubt = {
			fx = "calm",
			text = "The radio on the break room shelf confirms it: a real attack, a real warning. You lost two minutes you might not have. Every second counts now.",
			choices = {
				{ text = "Go to the basement. Now.", next = "shelter_choice", effects = { calm = -10 } },
			},
		},

		car = {
			fx = "dark",
			text = "The car park is chaos. The street outside is a solid wall of brake lights and horns. Nobody is going anywhere. A car window is a thin barrier against blast and radiation.",
			choices = {
				{ text = "Abandon the car and run back inside to shelter.", next = "shelter_choice", effects = { calm = -15, health = -10 } },
				{ text = "Stay in the car and hope the traffic clears.", next = "death", effects = { health = -100 }, note = "A car offers almost no protection." },
				{ text = "Run for the highway on foot.", next = "death", effects = { health = -100 }, note = "There is not enough time." },
			},
		},

		window = {
			fx = "dark",
			text = "You press your face to the glass. For a second you see nothing: the grey sky, the city. Then a light brighter than the sun swallows the horizon. Your eyes burn. The window shatters inward.",
			choices = {
				{ text = "Drop to the floor and crawl for the stairs.", next = "shelter_choice", effects = { health = -35, calm = -25 }, note = "You are blinded and cut by glass, but alive." },
			},
		},

		shelter_choice = {
			fx = "dark",
			text = "The stairwell echoes with feet. At the basement level, a heavy door stands open onto an underground car park. Two options: a concrete utility room deep in the building, or the open car park with its thin walls.\n\nIn the corridor, Mira from accounting is paralysed with fear, hands over her face.",
			choices = {
				{ text = "Take Mira's hand and bring her with you to the utility room.", next = "basement", effects = { calm = -5, set = { "helped_mira" } }, note = "Mira gives a small nod and follows." },
				{ text = "Go straight to the utility room.", next = "basement" },
				{ text = "Stay in the car park, close to the exit.", next = "death", effects = { health = -100 }, note = "The car park is too exposed." },
			},
		},

		basement = {
			fx = "dark",
			text = "The utility room is windowless and thick-walled. Pipes drip. You pull the door shut as the first tremor rolls through the building. Concrete dust trickles from the ceiling. Then a deep, endless roar, and the whole structure shudders.\n\nWhen it stops, the lights flicker out. In the dark you can hear your own breathing, and Mira's.",
			choices = {
				{ text = "Feel around the shelves for supplies.", next = "post_blast", effects = { give = { "radio" }, calm = 5 }, note = "Behind a box you find a battery radio." },
				{ text = "Sit tight and conserve energy.", next = "post_blast", effects = { calm = 5 } },
			},
		},

		post_blast = {
			fx = "dark",
			text = "Hours pass. The building groans but holds. Your head is ringing. Someone above is pounding on a pipe, an echo of something terrible. The dust is thick.\n\nThe urge to go up and look is almost unbearable.",
			choices = {
				{ text = "Stay inside. Wait for official word.", next = "wait", effects = { calm = -5 } },
				{ text = "Go upstairs to see what happened.", next = "outside", effects = { calm = -10 } },
			},
		},

		outside = {
			fx = "dark",
			text = "On the ground floor, the lobby is wrecked and a fine grey ash drifts through the broken doors. The sky is dim. You breathe in a mouthful of dust and cough hard. You realise the mistake: that air is not safe. Radioactive fallout is most dangerous in the first hours.",
			choices = {
				{ text = "Retreat to the basement and seal the door.", next = "wait", effects = { health = -25, calm = -15 }, note = "You will have to deal with the dust on your clothes." },
				{ text = "Walk out to find help.", next = "death", effects = { health = -100 }, note = "Fallout is lethal in the open." },
			},
		},

		wait = {
			fx = "dark",
			text = "Twelve hours in. Your mouth is dry. Without the battery radio, you would not have heard the emergency broadcast. With it, a calm voice repeats: \"Stay inside. Do not leave your shelter for at least 24 hours. Remove outer clothing. Wash exposed skin.\"",
			choices = {
				{ text = "Tune the radio and follow the instructions.", next = "decon", requires = { items = { "radio" } }, hiddenIfLocked = true, effects = { calm = 15 } },
				{ text = "Drink from your water bottle and wait.", next = "decon", requires = { items = { "water" } }, hiddenIfLocked = true, effects = { calm = 10 } },
				{ text = "Wait without any news.", next = "decon", effects = { health = -15, calm = -15 } },
			},
		},

		decon = {
			fx = "calm",
			text = "At the 24-hour mark, a faint voice on the radio, or just your own sense, says it is time. Rescue teams are sweeping the district. Dust still clings to your clothes and hair. Mira, if she is with you, is shivering.",
			choices = {
				{ text = "Remove your outer clothes, bag them, and wash off in the sink.", next = "rescue", effects = { calm = 10 }, note = "You wash your hair and face thoroughly." },
				{ text = "Leave everything as it is and walk out.", next = "rescue_sick", effects = { health = -40, calm = -10 } },
			},
		},

		rescue = {
			fx = "calm",
			text = "A team in protective suits finds you and checks you with a handheld detector. \"Clean,\" one of them says. \"You did everything right.\"",
			choices = {
				{ text = "Lead the others from the building to the evacuation point.", next = "hero_ending", requires = { flags = { "helped_mira" } }, hiddenIfLocked = true },
				{ text = "Follow the rescue team out.", next = "survived_ending" },
			},
		},

		rescue_sick = {
			fx = "calm",
			text = "The suited team finds you before you reach the street. Your clothes are still thick with dust. They hose you down, bag your clothes, and take you to a treatment centre. You will have weeks of treatment ahead, but you will live.",
			ending = { kind = "survived", title = "Weeks of Treatment" },
			lesson = "Removing outer clothing and washing can remove most radioactive dust. Do it as soon as it is safe.",
		},

		hero_ending = {
			fx = "calm",
			text = "You and Mira lead six others from the building, calling out for stragglers on the way. At the evacuation centre, the medic asks how you knew to stay in the basement. \"Get inside, stay inside, stay tuned,\" you say. \"Then help whoever you can.\"",
			ending = { kind = "hero", title = "Stay Tuned" },
			lesson = "Bringing others to shelter, and sharing the right information, saves more lives than acting alone.",
		},

		survived_ending = {
			fx = "calm",
			text = "You step out into a world turned grey. The wind carries the smell of smoke and wet concrete. The rescuers load you onto a truck with a hundred other survivors. You will never take an ordinary Tuesday for granted again.",
			ending = { kind = "survived", title = "The Quiet Morning" },
			lesson = "Shelter immediately and stay there for at least 24 hours unless authorities say otherwise.",
		},

		death = {
			fx = "dark",
			text = "There was never going to be enough time. A few minutes, and one wrong turn, made all the difference. Cities will rebuild, but you are not there to see it.",
			ending = { kind = "died", title = "Too Late" },
			lesson = "Civil-defence advice is blunt for a reason: get inside the nearest sturdy building immediately, move away from windows, and do not go outside until told it is safe.",
		},
	},
}
]=====])

local _ = make("Script", "Main", Server, [=====[
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
]=====])

local _ = make("ModuleScript", "Stage", Server, [=====[
--!nocheck
-- Builds a private walkable 3D set per player and turns story choices into
-- ProximityPrompts placed in it. Prompt hold timers are enforced by Roblox.
-- Each player's stage is far from everyone else's (slot * SPACING studs).

local Players = game:GetService("Players")

local Stage = {}

local SPACING = 400
local ORIGIN_Y = 500
local KEYS = { Enum.KeyCode.E, Enum.KeyCode.F, Enum.KeyCode.R, Enum.KeyCode.T }
local KEY_NAMES = { "E", "F", "R", "T" }

local stages = {} -- [Player] = { model, origin, world, prompts, slot, lastSpot, lastFx }
local slotTaken = {}

local function allocSlot()
	for i = 0, 63 do
		if not slotTaken[i] then
			slotTaken[i] = true
			return i
		end
	end
	return nil
end

-- Geometry helper handed to world builders.
-- d = { pos = Vector3 (relative to stage origin), size, color, material, transparency, canCollide, shape, rotY, name }
local function makePart(model, origin, d)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = d.size
	p.Color = d.color or Color3.fromRGB(200, 200, 200)
	p.Material = d.material or Enum.Material.SmoothPlastic
	p.Transparency = d.transparency or 0
	p.CanCollide = d.canCollide ~= false
	if d.shape then p.Shape = d.shape end
	if d.name then p.Name = d.name end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = origin * CFrame.new(d.pos) * CFrame.Angles(0, math.rad(d.rotY or 0), 0)
	p.Parent = d.parent or model
	return p
end

local function lobbyCFrame()
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then return spawn.CFrame + Vector3.new(0, 5, 0) end
	return CFrame.new(0, 10, 0)
end

local function teleport(player, st, spotName)
	local spot = st.world.spots[spotName]
	local char = player.Character
	if not (spot and char) then return end
	char:PivotTo(st.origin * CFrame.new(spot[1], 4, spot[2]) * CFrame.Angles(0, math.rad(spot[3] or 0), 0))
end

local function clearPrompts(st)
	for _, prompt in ipairs(st.prompts) do prompt:Destroy() end
	st.prompts = {}
end

function Stage.active(player)
	return stages[player] ~= nil
end

function Stage.leave(player, returnToLobby)
	local st = stages[player]
	if not st then return end
	clearPrompts(st)
	st.model:Destroy()
	slotTaken[st.slot] = nil
	stages[player] = nil
	if returnToLobby and player.Character then
		player.Character:PivotTo(lobbyCFrame())
	end
end

function Stage.enter(player, world)
	Stage.leave(player, false)
	local slot = allocSlot()
	if not slot then return false end
	local origin = CFrame.new(slot * SPACING, ORIGIN_Y, 0)
	local model = Instance.new("Model")
	model.Name = "Stage_" .. player.UserId
	model.Parent = workspace

	world.build(model, origin, function(d) return makePart(model, origin, d) end)

	-- Glowing beacons mark every place the player can act.
	for name, pos in pairs(world.markers) do
		makePart(model, origin, {
			name = name, pos = Vector3.new(pos[1], 2.5, pos[2]), size = Vector3.new(1.4, 1.4, 1.4),
			shape = Enum.PartType.Ball, color = Color3.fromRGB(255, 205, 60), material = Enum.Material.Neon,
			canCollide = false, transparency = 0.25,
		})
	end

	stages[player] = { model = model, origin = origin, world = world, prompts = {}, slot = slot }
	return true
end

-- Re-teleport after the character respawns (reset, fall, etc).
function Stage.recall(player)
	local st = stages[player]
	if st and st.lastSpot then teleport(player, st, st.lastSpot) end
end

-- Rebuilds prompts for the current node. Mutates view: marks choices that live
-- in the world (inWorld/key/place) and sets view.stage.
-- onChoose(player, choiceIndex) is called when a prompt is triggered.
function Stage.apply(player, view, onChoose)
	local st = stages[player]
	if not st then return end
	view.stage = true
	clearPrompts(st)

	local spotName = st.world.nodeSpots[view.nodeId]
	if spotName and spotName ~= st.lastSpot then
		st.lastSpot = spotName
		teleport(player, st, spotName)
	end

	if view.fx ~= st.lastFx then
		st.lastFx = view.fx
		if st.world.fx then st.world.fx(st.model, st.origin, view.fx) end
	end

	if view.ending then return end
	local anchors = st.world.anchors[view.nodeId] or {}
	local nodeId = view.nodeId
	for _, c in ipairs(view.choices) do
		local markerName = anchors[c.index]
		local marker = markerName and st.model:FindFirstChild(markerName)
		if marker then
			c.inWorld = true
			c.key = KEY_NAMES[c.index] or "E"
			c.place = st.world.labels[markerName] or markerName
			if not c.locked then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ObjectText = c.place
				prompt.ActionText = #c.text > 42 and (c.text:sub(1, 40) .. "...") or c.text
				prompt.HoldDuration = c.hold or 0
				prompt.KeyboardKeyCode = KEYS[c.index] or Enum.KeyCode.E
				prompt.MaxActivationDistance = 9
				prompt.RequiresLineOfSight = false
				prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
				prompt.Parent = marker
				local index = c.index
				prompt.Triggered:Connect(function(who)
					if who ~= player then return end
					if not stages[player] or stages[player].world ~= st.world then return end
					onChoose(player, index, nodeId)
				end)
				st.prompts[#st.prompts + 1] = prompt
			end
		end
	end
end

function Stage.setup()
	Players.PlayerRemoving:Connect(function(player) Stage.leave(player, false) end)
end

return Stage
]=====])

local _ = make("ModuleScript", "Classroom", Worlds, [=====[
--!nocheck
-- Walkable set for the "Shaking Ground" scenario.
-- Layout (x/z in studs from the stage origin, floor at y = 0):
--   Classroom  x -20..20, z -15..15   (door in the south wall at x 12..18)
--   Corridor   x -20..60, z  16..28   (blocked stairs west, lift north, back stairs east)
--   Field      x  70..130, z -10..50  (the assembly point outside)
--
-- Data tables (markers/labels/spots/nodeSpots/anchors) are plain data so
-- tools/test_story.py can check them against the story graph.

local Debris = game:GetService("Debris")

local WALL_H = 14
local WOOD = Color3.fromRGB(150, 110, 70)
local PAINT = Color3.fromRGB(225, 220, 205)
local GREY = Color3.fromRGB(120, 124, 130)

local World = {}

-- Places the player can act. { x, z }
World.markers = {
	m_desk = { 0, -2 },        -- your desk
	m_jay = { 5, 2 },          -- Jay, frozen in the aisle
	m_aisle = { 9, -4 },       -- the aisle by the window row
	m_door = { 13, 12 },       -- the classroom door
	m_frame = { 18, 12 },      -- the doorframe
	m_aid = { -18, 4 },        -- first-aid kit on the wall
	m_bag = { -6, -8 },        -- your backpack
	m_back_in = { 6, 10 },     -- back into the classroom
	m_crowd = { 14, 20 },      -- the packed corridor
	m_pile = { 24, 20 },       -- the pile-up by the stairs
	m_push = { -9, 24 },      -- the jammed main stairwell
	m_lift = { 10, 24 },       -- the lift
	m_backstairs = { 56, 22 }, -- the back stairs door
	m_gap = { 46, 22 },        -- the broken stairs
	m_exit = { 56, 26 },       -- onward and out
	m_here = { -2, 22 },       -- hold position in the corridor
	m_group = { -9, 19 },     -- stay with the group
}

-- Short names shown on the prompts and in the hint list.
World.labels = {
	m_desk = "Your desk", m_jay = "Jay", m_aisle = "The aisle", m_door = "Classroom door",
	m_frame = "Doorframe", m_aid = "First-aid kit", m_bag = "Your backpack", m_back_in = "Classroom",
	m_crowd = "The crowd", m_pile = "The pile-up", m_push = "Main stairwell", m_lift = "Lift",
	m_backstairs = "Back stairs", m_gap = "Broken stairs", m_exit = "Exit", m_here = "Right here",
	m_group = "The group",
}

-- Where the player is placed. { x, z, facingDegrees }
World.spots = {
	seat = { -7.5, 3, 0 },
	middle = { 2.5, 9, 0 },
	doorway = { 14, 14, 180 },
	crush = { 18, 22, 0 },
	corridor = { 30, 22, 90 },
	lift = { 10, 21, 0 },
	aftershock = { 3, 22, 0 },
	backstairs = { 50, 22, 90 },
	field = { 100, 20, 0 },
}

-- story node -> spot (teleport happens only when the spot changes)
World.nodeSpots = {
	start = "seat",
	run_door = "doorway",
	doorway = "doorway",
	hallway_crush = "crush",
	shaking_stops = "middle",
	corridor = "corridor",
	lift_stuck = "lift",
	back_stairs = "backstairs",
	back_stairs_dark = "backstairs",
	aftershock = "aftershock",
	rescue_group = "backstairs",
	outside_safe = "field",
	hero_ending = "field",
}

-- story node -> { [choiceIndex] = marker }. A choice with no entry is not placed
-- in the world; it stays a plain button in the story panel.
World.anchors = {
	start = { "m_desk", "m_door", "m_frame" },
	under_desk = { "m_jay", "m_aisle", "m_desk" },
	run_door = { "m_back_in", "m_push" },
	doorway = {}, -- single "carry on" choice stays a button
	hallway_crush = { "m_crowd", "m_pile" },
	shaking_stops = { "m_aid", "m_bag", "m_door" },
	corridor = { "m_lift", "m_backstairs", "m_gap", "m_group" },
	back_stairs = { "m_gap", "m_exit" },
	back_stairs_dark = { "m_exit", "m_here" },
	aftershock = { "m_here", "m_backstairs" },
	rescue_group = { "m_exit" },
}

function World.build(model, origin, part)
	local function box(name, x, y, z, sx, sy, sz, color, material, extra)
		local d = { name = name, pos = Vector3.new(x, y, z), size = Vector3.new(sx, sy, sz), color = color, material = material }
		for k, v in pairs(extra or {}) do d[k] = v end
		return part(d)
	end

	-- Floors
	box("ClassFloor", 0, -0.5, 0, 42, 1, 32, WOOD, Enum.Material.WoodPlanks)
	box("CorridorFloor", 20, -0.5, 22, 82, 1, 14, Color3.fromRGB(170, 170, 160), Enum.Material.Concrete)
	box("Field", 100, -0.5, 20, 70, 1, 70, Color3.fromRGB(80, 140, 70), Enum.Material.Grass)

	-- Classroom walls
	box("WallN", 0, WALL_H / 2, -15.5, 42, WALL_H, 1, PAINT)
	box("WallW", -20.5, WALL_H / 2, 0, 1, WALL_H, 32, PAINT)
	box("WallE", 20.5, WALL_H / 2, 0, 1, WALL_H, 32, PAINT)
	box("WallS1", -4, WALL_H / 2, 15.5, 32, WALL_H, 1, PAINT) -- x -20..12
	box("WallS2", 19, WALL_H / 2, 15.5, 4, WALL_H, 1, PAINT) -- x 17..21
	box("DoorLintel", 15, 11.5, 15.5, 6, 5, 1, PAINT) -- door gap x 12..18, 9 high
	box("Windows", 0, 8, -14.9, 30, 4, 0.3, Color3.fromRGB(170, 210, 235), Enum.Material.Glass, { transparency = 0.5, canCollide = false })

	-- Corridor walls
	box("CorN", 20, WALL_H / 2, 28.5, 82, WALL_H, 1, PAINT)
	box("CorS", 40, WALL_H / 2, 15.5, 40, WALL_H, 1, PAINT) -- x 20..60
	box("CorW", -20.5, WALL_H / 2, 22, 1, WALL_H, 14, PAINT)
	box("CorE", 60.5, WALL_H / 2, 22, 1, WALL_H, 14, PAINT)

	-- Ceilings (non-colliding so the camera never gets stuck on them)
	box("CeilingClass", 0, WALL_H + 0.5, 0, 42, 1, 32, Color3.fromRGB(235, 235, 235), nil, { canCollide = false })
	box("CeilingCor", 20, WALL_H + 0.5, 22, 82, 1, 14, Color3.fromRGB(235, 235, 235), nil, { canCollide = false })

	-- Lamps (toggled by World.fx)
	local lampFolder = Instance.new("Folder")
	lampFolder.Name = "Lamps"
	lampFolder.Parent = model
	local lampSpots = { { -10, -6 }, { 10, -6 }, { -10, 8 }, { 10, 8 }, { 0, 0 }, { 5, 22 }, { 25, 22 }, { 45, 22 }, { -10, 22 } }
	for _, p in ipairs(lampSpots) do
		local lamp = box("Lamp", p[1], WALL_H - 0.3, p[2], 5, 0.4, 2, Color3.fromRGB(255, 245, 210), Enum.Material.Neon, { canCollide = false, parent = lampFolder })
		local light = Instance.new("PointLight")
		light.Range = 26
		light.Brightness = 1.4
		light.Color = Color3.fromRGB(255, 240, 210)
		light.Parent = lamp
	end

	-- Whiteboard + teacher
	box("Whiteboard", 0, 7, -14.8, 16, 5, 0.3, Color3.fromRGB(250, 250, 250), Enum.Material.SmoothPlastic, { canCollide = false })
	local function person(name, x, z, shirt)
		box(name .. "Body", x, 3, z, 2, 3, 1, shirt)
		box(name .. "Legs", x, 1, z, 2, 2, 1, Color3.fromRGB(50, 55, 80))
		box(name .. "Head", x, 5, z, 1.5, 1.5, 1.5, Color3.fromRGB(235, 195, 150), nil, { shape = Enum.PartType.Ball })
	end
	person("Teacher", 0, -12, Color3.fromRGB(70, 120, 90))
	person("Jay", 5, 4, Color3.fromRGB(190, 60, 60))

	-- Desks and chairs in rows
	for row = 0, 2 do
		for col = -3, 3 do
			local x, z = col * 5, -6 + row * 6
			do
				box("Desk", x, 2.4, z, 3.6, 0.3, 2.4, Color3.fromRGB(205, 170, 120), Enum.Material.Wood)
				for _, lx in ipairs({ -1.5, 1.5 }) do
					for _, lz in ipairs({ -1, 1 }) do
						box("DeskLeg", x + lx, 1.1, z + lz, 0.25, 2.2, 0.25, GREY, Enum.Material.Metal)
					end
				end
				box("Chair", x, 1.5, z + 2.2, 1.8, 0.3, 1.8, Color3.fromRGB(60, 90, 160))
				box("ChairBack", x, 2.6, z + 3, 1.8, 2, 0.3, Color3.fromRGB(60, 90, 160))
			end
		end
	end

	-- First-aid kit and backpack
	box("FirstAid", -19.5, 5, 4, 0.8, 2, 2.6, Color3.fromRGB(245, 245, 245))
	box("FirstAidCross", -19.0, 5, 4, 0.2, 0.5, 1.6, Color3.fromRGB(220, 40, 40), Enum.Material.Neon, { canCollide = false })
	box("Backpack", -6, 1, -8, 1.6, 2, 1.2, Color3.fromRGB(40, 100, 200))

	-- Corridor: lift, blocked stairs, back stairs door
	box("LiftDoor", 10, 4.5, 27.8, 6, 9, 0.6, Color3.fromRGB(150, 155, 165), Enum.Material.Metal)
	box("LiftButton", 14, 4, 27.4, 0.6, 0.6, 0.4, Color3.fromRGB(255, 200, 50), Enum.Material.Neon, { canCollide = false })
	for i = 1, 6 do
		box("Rubble", -16 + (i % 3) * 2, 2 + (i % 2) * 2, 18 + i * 1.4, 5, 4, 3, Color3.fromRGB(110 + i * 6, 108, 104), Enum.Material.Concrete, { rotY = i * 23 })
	end
	box("BackStairsDoor", 60, 4.5, 22, 0.6, 9, 5, Color3.fromRGB(40, 110, 70), Enum.Material.Metal)

	-- Outside: fence and assembly sign
	box("Sign", 100, 6, 0, 8, 4, 0.5, Color3.fromRGB(40, 130, 70))
	box("SignPost", 100, 2, 0, 0.8, 4, 0.8, GREY)
	for i = 0, 8 do
		box("Fence", 70 + i * 8, 2, 52, 0.4, 4, 0.4, GREY)
	end
end

-- Disaster effects for each story "fx" tag.
function World.fx(model, origin, fx)
	local lamps = model:FindFirstChild("Lamps")
	if lamps then
		local on = fx ~= "dark"
		for _, lamp in ipairs(lamps:GetChildren()) do
			lamp.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			local light = lamp:FindFirstChildOfClass("PointLight")
			if light then light.Enabled = on end
		end
	end
	if fx == "quake" then
		-- ceiling tiles rain down, then clean themselves up
		for _ = 1, 8 do
			local tile = Instance.new("Part")
			tile.Size = Vector3.new(3, 0.4, 3)
			tile.Color = Color3.fromRGB(225, 225, 225)
			tile.CFrame = origin * CFrame.new(math.random(-16, 16), WALL_H - 1, math.random(-12, 12))
				* CFrame.Angles(math.rad(math.random(-20, 20)), math.rad(math.random(0, 360)), 0)
			tile.Parent = model
			Debris:AddItem(tile, 12)
		end
	end
end

return World
]=====])

local _ = make("LocalScript", "Main", Client, [=====[
-- Client UI for the branching survival story. All outcomes come from the
-- server; this script only renders views and sends the player's choices.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("StoryRemote")

local busy = false
local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

local TINTS = {
	none = { Color3.fromRGB(0, 0, 0), 1 },
	calm = { Color3.fromRGB(0, 0, 0), 1 },
	quake = { Color3.fromRGB(90, 70, 40), 0.82 },
	flood = { Color3.fromRGB(20, 80, 160), 0.78 },
	fire = { Color3.fromRGB(230, 90, 20), 0.78 },
	wave = { Color3.fromRGB(10, 110, 170), 0.72 },
	dark = { Color3.fromRGB(0, 0, 0), 0.55 },
}
local ENDING_COLORS = {
	survived = Color3.fromRGB(90, 190, 120),
	hero = Color3.fromRGB(250, 200, 60),
	died = Color3.fromRGB(220, 70, 70),
}
local ENDING_LABELS = { survived = "SURVIVED", hero = "HERO ENDING", died = "DID NOT SURVIVE" }

---------------------------------------------------------------- helpers

local function make(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	for _, child in ipairs(children or {}) do child.Parent = inst end
	return inst
end

local function corner(r) return make("UICorner", { CornerRadius = UDim.new(0, r or 10) }) end
local function pad(n)
	return make("UIPadding", {
		PaddingTop = UDim.new(0, n), PaddingBottom = UDim.new(0, n),
		PaddingLeft = UDim.new(0, n), PaddingRight = UDim.new(0, n),
	})
end

local function label(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or Color3.fromRGB(235, 235, 240)
	props.TextWrapped = true
	return make("TextLabel", props)
end

local function button(props)
	props.Font = props.Font or FONT_BOLD
	props.TextColor3 = props.TextColor3 or Color3.fromRGB(240, 240, 245)
	props.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(40, 46, 62)
	props.AutoButtonColor = true
	props.TextWrapped = true
	return make("TextButton", props, { corner(10) })
end

---------------------------------------------------------------- UI tree

local gui = make("ScreenGui", {
	Name = "DisasterUI", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 16, 24), BorderSizePixel = 0, Parent = gui })
local tint = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2, Parent = root })

-- Menu ---------------------------------------------------------------
local menu = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = root })
label({ Text = "SURVIVE THE DISASTER", Font = FONT_BOLD, TextSize = 42, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.new(0, 0, 0, 40), ZIndex = 3, Parent = menu })
label({ Text = "Choose a situation. Every choice changes the story. Can you find every ending?", TextSize = 20, TextColor3 = Color3.fromRGB(170, 175, 190), Size = UDim2.new(1, -40, 0, 30), Position = UDim2.new(0, 20, 0, 100), ZIndex = 3, Parent = menu })
local cards = make("ScrollingFrame", {
	Size = UDim2.new(1, -40, 1, -170), Position = UDim2.new(0, 20, 0, 150), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(), ZIndex = 3, Parent = menu,
}, {
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(270, 210), CellPadding = UDim2.fromOffset(16, 16),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
	}),
	pad(8),
})

-- Shop ---------------------------------------------------------------
local shopButton = button({ Text = "Starter Packs", TextSize = 18, Size = UDim2.fromOffset(160, 40), Position = UDim2.new(1, -180, 0, 48), BackgroundColor3 = Color3.fromRGB(190, 130, 30), ZIndex = 4, Parent = menu })
local shop = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 440),
	BackgroundColor3 = Color3.fromRGB(22, 25, 36), Visible = false, ZIndex = 20, Parent = gui,
}, { corner(16), pad(16) })
label({ Text = "Starter Packs", Font = FONT_BOLD, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -80, 0, 34), ZIndex = 21, Parent = shop })
label({ Text = "Packs are used up by one run. Every ending can be reached without them.", TextSize = 15, TextColor3 = Color3.fromRGB(170, 175, 190), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 38), ZIndex = 21, Parent = shop })
local shopClose = button({ Text = "X", TextSize = 18, Size = UDim2.fromOffset(40, 34), Position = UDim2.new(1, -40, 0, 0), ZIndex = 21, Parent = shop })
local shopList = make("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, -70), Position = UDim2.fromOffset(0, 68), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 21, Parent = shop,
}, { make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function buildShop(packs)
	for _, child in ipairs(shopList:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	for i, p in ipairs(packs) do
		local row = make("Frame", { Size = UDim2.new(1, -8, 0, 84), BackgroundColor3 = Color3.fromRGB(32, 37, 52), LayoutOrder = i, ZIndex = 22, Parent = shopList }, { corner(10), pad(10) })
		label({ Text = p.name .. "   (owned: " .. p.owned .. ")", Font = FONT_BOLD, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.6, 0, 0, 24), ZIndex = 23, Parent = row })
		label({ Text = p.desc, TextSize = 14, TextColor3 = Color3.fromRGB(170, 175, 190), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(0.6, 0, 0, 40), Position = UDim2.fromOffset(0, 26), ZIndex = 23, Parent = row })
		local buy = button({ Text = p.forSale and "Buy" or "Soon", TextSize = 16, Size = UDim2.new(0.34, 0, 0, 30), Position = UDim2.new(0.66, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(190, 130, 30), ZIndex = 23, Parent = row })
		local use = button({ Text = p.equipped and "Using next run" or "Use next run", TextSize = 14, Size = UDim2.new(0.34, 0, 0, 30), Position = UDim2.new(0.66, 0, 0, 36), BackgroundColor3 = p.equipped and Color3.fromRGB(50, 120, 90) or Color3.fromRGB(44, 52, 74), ZIndex = 23, Parent = row })
		if not p.forSale then buy.AutoButtonColor = false end
		buy.Activated:Connect(function()
			if not p.forSale or busy then return end
			busy = true
			local res = remote:InvokeServer("buy", p.id)
			busy = false
			if res and res.packs then buildShop(res.packs) end
		end)
		use.Activated:Connect(function()
			if busy or p.owned < 1 then return end
			busy = true
			local res = remote:InvokeServer("equip", { id = p.id, on = not p.equipped })
			busy = false
			if res and res.packs then buildShop(res.packs) end
		end)
	end
end
shopButton.Visible = false -- shown only if the server says the shop is enabled
shopButton.Activated:Connect(function() shop.Visible = true end)
shopClose.Activated:Connect(function() shop.Visible = false end)
ReplicatedStorage:WaitForChild("InventoryChanged").OnClientEvent:Connect(buildShop)

-- Game panel ---------------------------------------------------------
local game_ = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 3, Parent = root })
local panel = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.94),
	BackgroundColor3 = Color3.fromRGB(22, 25, 36), BackgroundTransparency = 0.05, ZIndex = 3, Parent = game_,
}, { corner(16), pad(16), make("UISizeConstraint", { MaxSize = Vector2.new(900, 4000) }) })
local PANEL_HOME = panel.Position -- reassigned by setLayout

local title = label({ Text = "", Font = FONT_BOLD, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -110, 0, 36), ZIndex = 4, Parent = panel })
local quit = button({ Text = "Menu", TextSize = 18, Size = UDim2.fromOffset(90, 34), Position = UDim2.new(1, -90, 0, 0), ZIndex = 4, Parent = panel })

local buttonsToggle = button({ Text = "Buttons: OFF", TextSize = 15, Size = UDim2.fromOffset(130, 34), Position = UDim2.new(1, -230, 0, 0), ZIndex = 4, Visible = false, Parent = panel })

local function bar(name, y, color)
	local holder = make("Frame", { Size = UDim2.new(0.5, -8, 0, 22), Position = UDim2.new(name == "Calm" and 0.5 or 0, name == "Calm" and 8 or 0, 0, y), BackgroundColor3 = Color3.fromRGB(10, 12, 18), ZIndex = 4, Parent = panel }, { corner(8) })
	local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, ZIndex = 5, Parent = holder }, { corner(8) })
	label({ Text = name, TextSize = 14, Font = FONT_BOLD, Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = holder })
	return fill
end
local healthFill = bar("Health", 44, Color3.fromRGB(200, 70, 70))
local calmFill = bar("Calm", 44, Color3.fromRGB(70, 140, 210))
local itemsLabel = label({ Text = "Items: none", TextSize = 16, TextColor3 = Color3.fromRGB(180, 185, 200), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, 72), ZIndex = 4, Parent = panel })

local storyScroll = make("ScrollingFrame", {
	Size = UDim2.new(1, 0, 0.4, 0), Position = UDim2.new(0, 0, 0, 100), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 4, Parent = panel,
})
local storyText = make("TextButton", {
	Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Font = FONT, TextSize = 21,
	TextColor3 = Color3.fromRGB(235, 235, 240), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	ZIndex = 4, Parent = storyScroll,
})
local noteLabel = label({ Text = "", TextSize = 17, Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(255, 205, 110), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0.4, 104), ZIndex = 4, Parent = panel })
local choiceScroll = make("ScrollingFrame", {
	Size = UDim2.new(1, 0, 0.6, -150), Position = UDim2.new(0.0, 0, 0.4, 148), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 4, Parent = panel,
}, { make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

---------------------------------------------------------------- behaviour

local currentView = nil
local typeToken = 0
local fxToken = 0
local skipConn = nil

local stageMode = false   -- story is playing inside a 3D stage
local buttonsMode = false -- in stage mode: also allow clicking choices

local function setLayout(world)
	stageMode = world
	root.BackgroundTransparency = world and 1 or 0
	buttonsToggle.Visible = world
	if world then
		panel.AnchorPoint = Vector2.new(0.5, 1)
		PANEL_HOME = UDim2.fromScale(0.5, 0.985)
		panel.Size = UDim2.fromScale(0.94, 0.5)
		panel.BackgroundTransparency = 0.12
		storyScroll.Size = UDim2.new(1, 0, 0, 110)
		noteLabel.Size = UDim2.new(1, 0, 0, 26)
		noteLabel.Position = UDim2.new(0, 0, 0, 214)
		choiceScroll.Position = UDim2.new(0, 0, 0, 244)
		choiceScroll.Size = UDim2.new(1, 0, 1, -246)
		storyText.TextSize = 18
	else
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		PANEL_HOME = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromScale(0.94, 0.94)
		panel.BackgroundTransparency = 0.05
		storyScroll.Size = UDim2.new(1, 0, 0.4, 0)
		noteLabel.Size = UDim2.new(1, 0, 0, 40)
		noteLabel.Position = UDim2.new(0, 0, 0.4, 104)
		choiceScroll.Position = UDim2.new(0, 0, 0.4, 148)
		choiceScroll.Size = UDim2.new(1, 0, 0.6, -150)
		storyText.TextSize = 21
	end
	panel.Position = PANEL_HOME
end

local function setTint(fx)
	local t = TINTS[fx] or TINTS.none
	local transparency = stageMode and (1 - (1 - t[2]) * 0.5) or t[2]
	TweenService:Create(tint, TweenInfo.new(0.8), { BackgroundColor3 = t[1], BackgroundTransparency = transparency }):Play()
end

local function humanoid()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

-- UI mode: shake the story panel. Stage mode: shake the 3D camera.
local function shake(seconds)
	fxToken += 1
	local mine = fxToken
	task.spawn(function()
		local t0 = os.clock()
		while fxToken == mine and os.clock() - t0 < seconds do
			local k = 1 - (os.clock() - t0) / seconds
			if stageMode then
				local hum = humanoid()
				if hum then hum.CameraOffset = Vector3.new(math.random(-10, 10) / 10 * k, math.random(-10, 10) / 10 * k, 0) end
			else
				panel.Position = PANEL_HOME + UDim2.fromOffset(math.random(-8, 8) * k, math.random(-8, 8) * k)
			end
			RunService.RenderStepped:Wait()
		end
		if fxToken == mine then
			panel.Position = PANEL_HOME
			local hum = humanoid()
			if hum then hum.CameraOffset = Vector3.zero end
		end
	end)
end

local function clearChoices()
	for _, child in ipairs(choiceScroll:GetChildren()) do
		if not child:IsA("UIListLayout") then child:Destroy() end
	end
end

local function updateStats(view)
	TweenService:Create(healthFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.clamp(view.health / view.maxHealth, 0, 1), 1) }):Play()
	TweenService:Create(calmFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.clamp(view.calm / 100, 0, 1), 1) }):Play()
	local items = #view.items > 0 and table.concat(view.items, ", ") or "none"
	itemsLabel.Text = "Items: " .. items .. (view.panicked and "     PANICKING: risky moves are harder" or "")
	itemsLabel.TextColor3 = view.panicked and Color3.fromRGB(255, 130, 110) or Color3.fromRGB(180, 185, 200)
end

local showMenu, present -- forward declarations

local function showEnding(view)
	clearChoices()
	local color = ENDING_COLORS[view.ending.kind] or Color3.new(1, 1, 1)
	local card = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(14, 16, 24), ZIndex = 5, Parent = choiceScroll }, {
		corner(12), pad(12),
		make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	label({ Text = (ENDING_LABELS[view.ending.kind] or "THE END") .. ": " .. view.ending.title, Font = FONT_BOLD, TextSize = 24, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 6, LayoutOrder = 1, Parent = card })
	label({ Text = "What to remember: " .. (view.ending.lesson or ""), TextSize = 18, TextColor3 = Color3.fromRGB(200, 205, 220), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 6, LayoutOrder = 2, Parent = card })
	label({ Text = ("You made %d decisions."):format(view.ending.steps or 0), TextSize = 16, TextColor3 = Color3.fromRGB(150, 155, 170), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 22), ZIndex = 6, LayoutOrder = 3, Parent = card })
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, ZIndex = 6, LayoutOrder = 4, Parent = card }, {
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})
	local again = button({ Text = "Try a different path", TextSize = 18, Size = UDim2.new(0.5, -4, 1, 0), BackgroundColor3 = Color3.fromRGB(50, 120, 90), ZIndex = 7, Parent = row })
	local back = button({ Text = "Back to menu", TextSize = 18, Size = UDim2.new(0.5, -4, 1, 0), ZIndex = 7, Parent = row })
	again.Activated:Connect(function()
		if busy then return end
		busy = true
		local v = remote:InvokeServer("start", view.scenarioId)
		busy = false
		if v and not v.error then present(v) end
	end)
	back.Activated:Connect(function() showMenu() end)
end

local function sendChoice(index)
	if busy then return end
	busy = true
	local v = remote:InvokeServer("choose", index)
	busy = false
	if v and not v.error then
		present(v)
	elseif v and v.error == "hold longer" then
		noteLabel.Text = "You let go too early. Hold the button for the full time."
	end
end

-- Press-and-hold: the fill bar grows over c.hold seconds; releasing early cancels.
-- The server re-checks the elapsed time, so this is not just cosmetic.
local function attachHold(b, c)
	local fill = make("Frame", {
		Position = UDim2.fromOffset(-12, -12), Size = UDim2.new(0, 0, 1, 24), BackgroundColor3 = Color3.fromRGB(110, 190, 140),
		BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 6, Parent = b,
	}, { corner(10) })
	local holding = false
	b.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		if holding or busy then return end
		holding = true
		local startAt = os.clock()
		task.spawn(function() remote:InvokeServer("holdbegin", c.index) end)
		local conn
		local function stop(done)
			holding = false
			if conn then conn:Disconnect() end
			if done then sendChoice(c.index) else fill.Size = UDim2.new(0, 0, 1, 24) end
		end
		conn = RunService.RenderStepped:Connect(function()
			if not holding then return end
			local a = math.min((os.clock() - startAt) / c.hold, 1)
			fill.Size = UDim2.new(a, 24 * a, 1, 24)
			if a >= 1 then stop(true) end
		end)
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End and holding then stop(false) end
		end)
	end)
end

local function showChoices(view)
	clearChoices()
	if stageMode then
		make("TextLabel", {
			Text = buttonsMode and "Tap an option, or walk to its glowing orb." or "Walk to a glowing orb and press the key shown. Some actions need you to hold it.",
			BackgroundTransparency = 1, Font = FONT, TextSize = 15, TextColor3 = Color3.fromRGB(150, 155, 170), TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -8, 0, 20), LayoutOrder = 0, ZIndex = 5, Parent = choiceScroll,
		})
	end
	for _, c in ipairs(view.choices) do
		local locked = c.locked
		local hintOnly = stageMode and c.inWorld and not buttonsMode
		local text = c.text
		if c.inWorld and c.key then text = ("[%s at %s]  %s"):format(c.key, c.place, text) end
		if c.hold then text = text .. ("   (hold %gs)"):format(c.hold) end
		if locked then text = text .. "   [" .. (c.lockReason or "locked") .. "]" end
		if c.risky and not locked then text = text .. "   (risky)" end
		local dim = locked or hintOnly
		local b = button({
			Text = text, TextSize = stageMode and 16 or 19, TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = dim and Color3.fromRGB(30, 33, 44) or Color3.fromRGB(44, 52, 74),
			TextColor3 = dim and Color3.fromRGB(150, 155, 170) or Color3.fromRGB(240, 240, 245),
			AutoButtonColor = not dim, Active = not hintOnly, LayoutOrder = c.index, ZIndex = 5, Parent = choiceScroll,
		})
		if locked then b.TextColor3 = Color3.fromRGB(110, 115, 130) end
		pad(12).Parent = b
		if not dim then
			if c.hold then
				attachHold(b, c)
			else
				b.Activated:Connect(function() sendChoice(c.index) end)
			end
		end
	end
end

local function render(view)
	currentView = view
	setLayout(view.stage == true and not view.ending)
	title.Text = view.title
	noteLabel.Text = view.note or ""
	updateStats(view)
	setTint(view.fx)
	clearChoices()
	storyScroll.CanvasPosition = Vector2.new()

	typeToken += 1
	local mine = typeToken
	storyText.Text = view.text
	storyText.MaxVisibleGraphemes = 0
	if view.fx == "quake" then shake(2.5) elseif view.fx == "wave" then shake(1.5) end

	local total = utf8.len(view.text) or #view.text
	local function finish()
		storyText.MaxVisibleGraphemes = -1
		if view.ending then showEnding(view) else showChoices(view) end
	end
	task.spawn(function()
		for i = 1, total do
			if typeToken ~= mine then return end
			storyText.MaxVisibleGraphemes = i
			if i % 2 == 0 then task.wait(0.012) end
		end
		if typeToken == mine then finish() end
	end)
	-- Click the text to skip the typewriter effect.
	if skipConn then skipConn:Disconnect() end
	skipConn = storyText.Activated:Connect(function()
		if typeToken == mine and storyText.MaxVisibleGraphemes ~= -1 then
			typeToken += 1
			finish()
		end
	end)
end
function present(view)
	if not game_.Visible then
		menu.Visible = false
		game_.Visible = true
	end
	render(view)
end

buttonsToggle.Activated:Connect(function()
	buttonsMode = not buttonsMode
	buttonsToggle.Text = buttonsMode and "Buttons: ON" or "Buttons: OFF"
	if currentView and not currentView.ending and storyText.MaxVisibleGraphemes == -1 then showChoices(currentView) end
end)

-- Choices made at a 3D prompt arrive here instead of as an InvokeServer reply.
ReplicatedStorage:WaitForChild("StoryUpdate").OnClientEvent:Connect(function(view)
	present(view)
end)

local function buildCards(list)
	for _, child in ipairs(cards:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	for i, s in ipairs(list) do
		local card = button({
			Text = "", BackgroundColor3 = Color3.fromRGB(28, 33, 48), LayoutOrder = i, ZIndex = 4, Parent = cards,
		})
		pad(12).Parent = card
		label({ Text = s.icon, TextSize = 34, Size = UDim2.new(0, 50, 0, 44), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = card })
		label({ Text = s.title, Font = FONT_BOLD, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 46), ZIndex = 5, Parent = card })
		label({ Text = s.place .. " / " .. s.disaster .. " / " .. s.difficulty, TextSize = 13, TextColor3 = Color3.fromRGB(240, 170, 90), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 72), ZIndex = 5, Parent = card })
		label({ Text = s.blurb, TextSize = 14, TextColor3 = Color3.fromRGB(170, 175, 190), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.new(0, 0, 0, 94), ZIndex = 5, Parent = card })
		label({ Text = ("Endings found: %d / %d"):format(s.endingsFound, s.endingsTotal), Font = FONT_BOLD, TextSize = 14, TextColor3 = Color3.fromRGB(120, 200, 150), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -18), ZIndex = 5, Parent = card })
		card.Activated:Connect(function()
			if busy then return end
			busy = true
			local v = remote:InvokeServer("start", s.id)
			busy = false
			if v and not v.error then present(v) end
		end)
	end
end

function showMenu()
	typeToken += 1
	fxToken += 1
	setLayout(false)
	local hum = humanoid()
	if hum then hum.CameraOffset = Vector3.zero end
	setTint("none")
	game_.Visible = false
	menu.Visible = true
	local res = remote:InvokeServer("menu")
	if res and res.menu then buildCards(res.menu) end
	if res and res.packs then buildShop(res.packs) end
	shopButton.Visible = res ~= nil and res.shopEnabled == true
end

quit.Activated:Connect(function() if not busy then showMenu() end end)

showMenu()
]=====])

print("Survive the Disaster installed. Press Play!")
