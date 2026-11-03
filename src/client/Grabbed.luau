-- Lo que vive la víctima del Atrapador: la lengua la jala hacia él (este cliente mueve su propio personaje, así no pelea con el
-- servidor), se puede mover y disparar flojo, y forcejea con Espacio (o tocando el botón en celular) para soltarse. El servidor
-- publica en el jugador GrabbedId (el GrabId del zombie) y GrabProgress (0 a 1).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Controls = require(script.Parent.Controls)
local Sfx = require(script.Parent.Sfx)

local G = Config.Grabber
local player = Players.LocalPlayer

local Grabbed = {}

local gui, title, hint, barFill, vignette, button
local pull -- { velocity, attachment, walkSpeed, humanoid }
local lastPress = 0

local function font(weight)
	return Font.new("rbxasset://fonts/families/Oswald.json", weight or Enum.FontWeight.Bold)
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font()
	l.TextStrokeTransparency = 0.45
	for key, value in props do
		l[key] = value
	end
	l.Parent = parent
	return l
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "GrabbedHud"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 66
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- viñeta roja que late
	vignette = Instance.new("Frame")
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(190, 20, 30)
	stroke.Thickness = 46
	stroke.Transparency = 0.5
	stroke.Parent = vignette

	title = label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.14, 0),
		Size = UDim2.fromOffset(700, 70),
		TextSize = 60,
		TextColor3 = Color3.fromRGB(255, 70, 58),
		Text = "GRABBED!",
	})
	hint = label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.14, 66),
		Size = UDim2.fromOffset(760, 34),
		TextSize = 28,
		TextColor3 = Color3.fromRGB(240, 232, 220),
		Text = "MASH SPACE TO BREAK FREE",
	})
	label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.14, 102),
		Size = UDim2.fromOffset(760, 26),
		TextSize = 22,
		TextColor3 = Color3.fromRGB(190, 182, 170),
		Text = "OR SHOOT THE TONGUE",
	})

	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0.14, 140)
	bar.Size = UDim2.fromOffset(380, 16)
	bar.BackgroundColor3 = Color3.fromRGB(20, 12, 12)
	bar.BorderSizePixel = 0
	bar.Parent = gui
	local barStroke = Instance.new("UIStroke")
	barStroke.Color = Color3.fromRGB(240, 232, 220)
	barStroke.Thickness = 2
	barStroke.Parent = bar
	barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = Color3.fromRGB(240, 70, 56)
	barFill.BorderSizePixel = 0
	barFill.Parent = bar

	-- botón para celular
	button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -40)
	button.Size = UDim2.fromOffset(300, 96)
	button.BackgroundColor3 = Color3.fromRGB(190, 24, 34)
	button.BorderSizePixel = 0
	button.FontFace = font()
	button.TextSize = 40
	button.TextColor3 = Color3.fromRGB(250, 244, 232)
	button.Text = "BREAK FREE"
	button.AutoButtonColor = true
	button.Visible = false
	button.Parent = gui
end

local function struggle()
	local now = os.clock()
	if now - lastPress < 1 / G.StruggleMaxRate then
		return
	end
	lastPress = now
	Remotes.Struggle:FireServer()
	Sfx.play("Struggle", 0.08)
end

local function stopPull()
	if not pull then
		return
	end
	pull.velocity:Destroy()
	pull.attachment:Destroy()
	if pull.humanoid and pull.humanoid.Parent then
		pull.humanoid.WalkSpeed = pull.walkSpeed
	end
	pull = nil
end

local function startPull(root, humanoid)
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.PlaneVelocity = Vector2.zero
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.MaxPlanarAxesForce = Vector2.new(1e6, 1e6)
	velocity.Parent = root
	pull = { velocity = velocity, attachment = attachment, humanoid = humanoid, walkSpeed = humanoid.WalkSpeed }
end

local function findGrabber(id)
	local folder = workspace:FindFirstChild("Zombies")
	if not folder then
		return nil
	end
	for _, model in folder:GetChildren() do
		if model:GetAttribute("GrabId") == id then
			return model
		end
	end
	return nil
end

local function step()
	local id = player:GetAttribute("GrabbedId")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (id and root and humanoid and humanoid.Health > 0) then
		if gui.Enabled then
			gui.Enabled = false
			stopPull()
		end
		return
	end
	if not gui.Enabled then
		gui.Enabled = true
		button.Visible = Controls.isTouch()
		hint.Text = Controls.isTouch() and "TAP TO BREAK FREE" or "MASH SPACE TO BREAK FREE"
		Sfx.play("TongueHit")
	end
	if not pull then
		startPull(root, humanoid)
	end

	local progress = player:GetAttribute("GrabProgress") or 0
	barFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	local beat = 0.5 + 0.5 * math.sin(os.clock() * (6 + 6 * progress))
	vignette.UIStroke.Transparency = 0.35 + 0.4 * beat
	title.Rotation = math.sin(os.clock() * 40) * 1.2

	-- Tirón hacia el Atrapador, con el movimiento del jugador restando
	local grabber = findGrabber(id)
	humanoid.WalkSpeed = 0
	local planar = Vector3.zero
	-- el servidor mide la distancia hasta el centro del zombie, así que aquí también
	if grabber and grabber.PrimaryPart then
		local target = grabber.PrimaryPart.Position
		local to = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
		if to.Magnitude > G.HoldRange - 0.5 then
			planar = to.Unit * G.PullSpeed
		end
	end
	local move = humanoid.MoveDirection
	planar += Vector3.new(move.X, 0, move.Z) * (Config.Player.WalkSpeed or 16) * G.Resist
	pull.velocity.PlaneVelocity = Vector2.new(planar.X, planar.Z)
end

function Grabbed.start()
	build()
	button.Activated:Connect(struggle)
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Space and gui.Enabled then
			struggle()
		end
	end)
	player:GetAttributeChangedSignal("GrabbedId"):Connect(function()
		if not player:GetAttribute("GrabbedId") then
			gui.Enabled = false
			stopPull()
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return Grabbed
