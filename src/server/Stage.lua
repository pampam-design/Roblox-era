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
