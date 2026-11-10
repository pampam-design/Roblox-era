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
