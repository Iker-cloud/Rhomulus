-- Aviso rápido arriba de la pantalla cuando sale un Tanque o un Atrapador: tira de papel de expediente con banda roja, que cae,
-- se queda un instante y se va sola (~1,6 s). Sale al aparecer el zombie en workspace.Zombies (el servidor pone el atributo Kind
-- antes de colgarlo). Los textos están en inglés y Lang.watch los traduce.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer

local SpawnAlert = {}

local INK = Color3.fromRGB(36, 30, 24)
local PAPER = Color3.fromRGB(228, 214, 178)
local RED = Color3.fromRGB(176, 48, 44)
local TYPEWRITER = Font.fromEnum(Enum.Font.SpecialElite)
local HEAD = (function()
	local ok, font = pcall(function()
		return Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.ExtraBold)
	end)
	return ok and font or Font.fromEnum(Enum.Font.Oswald)
end)()

local ALERTS = {
	Tank = { Title = "TANK INCOMING", Text = "Aim for the head. Stay together.", Sound = "AlertTank" },
	Grabber = { Title = "GRABBER NEARBY", Text = "Shoot the tongue or struggle free.", Sound = "AlertGrabber" },
}
local GAP = 4 -- segundos mínimos entre dos avisos iguales (una horda puede traer varios)

local gui, banner, titleLabel, textLabel, shownAt
local lastShown = {}
local token = 0

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	for key, value in props do
		l[key] = value
	end
	l.Parent = parent
	return l
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "SpawnAlert"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 55
	gui.Parent = player:WaitForChild("PlayerGui")

	banner = Instance.new("Frame")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Size = UDim2.fromOffset(500, 78)
	banner.Position = UDim2.new(0.5, 0, 0, -120)
	banner.BackgroundColor3 = PAPER
	banner.BorderSizePixel = 0
	banner.Rotation = -1
	banner.Visible = false
	banner.Parent = gui
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new(Color3.fromRGB(238, 226, 194), Color3.fromRGB(212, 194, 156))
	shade.Rotation = 80
	shade.Parent = banner
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 3
	stroke.Parent = banner
	local scale = Instance.new("UIScale")
	scale.Name = "Fit"
	scale.Parent = banner

	local band = Instance.new("Frame")
	band.Size = UDim2.fromOffset(74, 78)
	band.BackgroundColor3 = RED
	band.BorderSizePixel = 0
	band.Parent = banner
	label(band, {
		Size = UDim2.fromScale(1, 1),
		Text = "!",
		FontFace = HEAD,
		TextSize = 60,
		TextColor3 = PAPER,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	titleLabel = label(banner, {
		Position = UDim2.fromOffset(90, 6),
		Size = UDim2.fromOffset(400, 40),
		FontFace = HEAD,
		TextSize = 34,
		TextColor3 = INK,
	})
	textLabel = label(banner, {
		Position = UDim2.fromOffset(92, 46),
		Size = UDim2.fromOffset(400, 24),
		FontFace = TYPEWRITER,
		TextSize = 17,
		TextColor3 = RED,
	})
end

local function show(kind)
	local def = ALERTS[kind]
	if not def or not banner then
		return
	end
	local now = os.clock()
	if now - (lastShown[kind] or -math.huge) < GAP then
		return
	end
	lastShown[kind] = now
	token += 1
	local mine = token

	titleLabel.Text = def.Title
	textLabel.Text = def.Text
	banner.Fit.Scale = math.min(1, gui.AbsoluteSize.X / 540)
	banner.Visible = true
	banner.Rotation = -4
	banner.Position = UDim2.new(0.5, 0, 0, -120)
	Sfx.play(def.Sound)

	TweenService:Create(banner, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 56),
		Rotation = -1,
	}):Play()
	task.delay(1.35, function()
		if mine ~= token then
			return
		end
		local out = TweenService:Create(banner, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -120),
		})
		out:Play()
		out.Completed:Once(function()
			if mine == token then
				banner.Visible = false
			end
		end)
	end)
end

function SpawnAlert.start()
	build()
	local folder = workspace:WaitForChild("Zombies")
	folder.ChildAdded:Connect(function(model)
		local kind = model:GetAttribute("Kind")
		if not kind then
			task.wait()
			kind = model:GetAttribute("Kind")
		end
		if kind then
			show(kind)
		end
	end)
end

return SpawnAlert
