-- Client UI for the branching survival story. All outcomes come from the
-- server; this script only renders views and sends the player's choices.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("StoryRemote")

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

-- Game panel ---------------------------------------------------------
local game_ = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 3, Parent = root })
local panel = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.94),
	BackgroundColor3 = Color3.fromRGB(22, 25, 36), BackgroundTransparency = 0.05, ZIndex = 3, Parent = game_,
}, { corner(16), pad(16), make("UISizeConstraint", { MaxSize = Vector2.new(900, 4000) }) })
local PANEL_HOME = panel.Position

local title = label({ Text = "", Font = FONT_BOLD, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -110, 0, 36), ZIndex = 4, Parent = panel })
local quit = button({ Text = "Menu", TextSize = 18, Size = UDim2.fromOffset(90, 34), Position = UDim2.new(1, -90, 0, 0), ZIndex = 4, Parent = panel })

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

local busy = false
local currentView = nil
local typeToken = 0
local fxToken = 0
local skipConn = nil

local function setTint(fx)
	local t = TINTS[fx] or TINTS.none
	TweenService:Create(tint, TweenInfo.new(0.8), { BackgroundColor3 = t[1], BackgroundTransparency = t[2] }):Play()
end

local function shake(seconds)
	fxToken += 1
	local mine = fxToken
	task.spawn(function()
		local t0 = os.clock()
		while fxToken == mine and os.clock() - t0 < seconds do
			local k = 1 - (os.clock() - t0) / seconds
			panel.Position = PANEL_HOME + UDim2.fromOffset(math.random(-8, 8) * k, math.random(-8, 8) * k)
			RunService.RenderStepped:Wait()
		end
		if fxToken == mine then panel.Position = PANEL_HOME end
	end)
end

local function clearChoices()
	for _, child in ipairs(choiceScroll:GetChildren()) do
		if not child:IsA("UIListLayout") then child:Destroy() end
	end
end

local function updateStats(view)
	TweenService:Create(healthFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.clamp(view.health / 100, 0, 1), 1) }):Play()
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

local function showChoices(view)
	clearChoices()
	for _, c in ipairs(view.choices) do
		local locked = c.locked
		local text = c.text
		if locked then text = text .. "   [" .. (c.lockReason or "locked") .. "]" end
		if c.risky and not locked then text = text .. "   (risky)" end
		local b = button({
			Text = text, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = locked and Color3.fromRGB(30, 33, 44) or Color3.fromRGB(44, 52, 74),
			TextColor3 = locked and Color3.fromRGB(110, 115, 130) or Color3.fromRGB(240, 240, 245),
			AutoButtonColor = not locked, LayoutOrder = c.index, ZIndex = 5, Parent = choiceScroll,
		})
		pad(12).Parent = b
		if not locked then
			b.Activated:Connect(function()
				if busy then return end
				busy = true
				local v = remote:InvokeServer("choose", c.index)
				busy = false
				if v and not v.error then present(v) end
			end)
		end
	end
end

local function render(view)
	currentView = view
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
	panel.Position = PANEL_HOME
	setTint("none")
	game_.Visible = false
	menu.Visible = true
	local res = remote:InvokeServer("menu")
	if res and res.menu then buildCards(res.menu) end
end

quit.Activated:Connect(function() if not busy then showMenu() end end)

showMenu()
