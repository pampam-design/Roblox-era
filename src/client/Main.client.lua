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
