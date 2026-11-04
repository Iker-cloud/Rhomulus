-- Efectos del Atrapador: el láser rojo con el que apunta, la lengua larga (en el aire, tensa y recogiéndose), el aviso de
-- "te está apuntando" y sus sonidos. Todo sale de los atributos que publica server/Grabber en el zombie (TongueState, TongueT0,
-- TongueDur, TongueAim, TongueTarget); el cuerpo lo anima ZombieAnimator.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer

local GrabberFx = {}

local TONGUE_COLOR = Color3.fromRGB(176, 38, 56)
local LASER_COLOR = Color3.fromRGB(255, 40, 40)
local RETRACT_TIME = 0.35

local rigs = {} -- [Model] = { mouth, tongue, laser, tip, endPoint, ... }

local function anchorPart(name)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.Parent = workspace
	return part
end

local function newBeam(parent, a0, a1, props)
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.FaceCamera = true
	beam.Enabled = false
	for key, value in props do
		beam[key] = value
	end
	beam.Parent = parent
	return beam
end

local function register(model)
	if rigs[model] or model:GetAttribute("Kind") ~= "Grabber" then
		return
	end
	local startPart = anchorPart("TongueStart")
	local endPart = anchorPart("TongueEnd")
	local a0 = Instance.new("Attachment")
	a0.Parent = startPart
	local a1 = Instance.new("Attachment")
	a1.Parent = endPart
	local tongue = newBeam(startPart, a0, a1, {
		Color = ColorSequence.new(TONGUE_COLOR),
		Width0 = 0.55,
		Width1 = 0.42,
		Segments = 24,
		LightEmission = 0.05,
	})
	local laser = newBeam(startPart, a0, a1, {
		Color = ColorSequence.new(LASER_COLOR),
		Width0 = 0.1,
		Width1 = 0.1,
		Segments = 2,
		LightEmission = 1,
	})
	-- la punta de la lengua: una bola roja
	local tip = Instance.new("Part")
	tip.Name = "TongueTip"
	tip.Shape = Enum.PartType.Ball
	tip.Size = Vector3.one * 0.95
	tip.Color = TONGUE_COLOR
	tip.Material = Enum.Material.SmoothPlastic
	tip.Anchored = true
	tip.CanCollide = false
	tip.CanQuery = false
	tip.CanTouch = false
	tip.CastShadow = false
	tip.Transparency = 1
	tip.Parent = workspace

	local rig = { startPart = startPart, endPart = endPart, tongue = tongue, laser = laser, tip = tip, lastEnd = Vector3.zero, state = nil }
	rigs[model] = rig

	-- Sonidos al cambiar de estado
	model:GetAttributeChangedSignal("TongueState"):Connect(function()
		local state = model:GetAttribute("TongueState")
		local mouth = model:FindFirstChild("boca") or model:FindFirstChild("Head")
		local position = mouth and mouth.Position or model:GetPivot().Position
		if state == "aim" then
			Sfx.play3D("GrabberAim", position)
		elseif state == "shot" then
			Sfx.play3D("TongueShot", position)
		elseif state == "hold" then
			Sfx.play3D("TongueHit", rig.lastEnd)
		elseif state == "retract" and rig.state == "hold" then
			Sfx.play3D("TongueSnap", position)
		end
		rig.state = state
	end)

	model.Destroying:Connect(function()
		rigs[model] = nil
		startPart:Destroy()
		endPart:Destroy()
		tip:Destroy()
	end)
end

-- Aviso de pantalla cuando un Atrapador te apunta
local warning
local function buildWarning()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GrabberWarning"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 65
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0.16, 0)
	label.Size = UDim2.fromOffset(700, 60)
	label.BackgroundTransparency = 1
	label.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
	label.TextSize = 44
	label.TextColor3 = Color3.fromRGB(255, 60, 52)
	label.TextStrokeTransparency = 0.4
	label.Text = "GRABBER LOCKING ON!"
	label.Parent = gui
	local sub = label:Clone()
	sub.Position = UDim2.new(0.5, 0, 0.16, 54)
	sub.TextSize = 26
	sub.TextColor3 = Color3.fromRGB(240, 232, 220)
	sub.Text = "Break its line of sight or dodge sideways"
	sub.Parent = gui
	return gui
end

local function update()
	local serverNow = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local locked = false
	for model, rig in rigs do
		local state = model:GetAttribute("TongueState")
		local mouthPart = model:FindFirstChild("boca") or model:FindFirstChild("Head")
		local active = state ~= nil and mouthPart ~= nil and (mouthPart.Position - camera.CFrame.Position).Magnitude < 260
		if not active then
			rig.tongue.Enabled = false
			rig.laser.Enabled = false
			rig.tip.Transparency = 1
		else
			local mouth = mouthPart.Position
			local t = model:GetAttribute("TongueT0") or serverNow
			local dur = model:GetAttribute("TongueDur") or 1
			local victimId = model:GetAttribute("TongueTarget")
			local victim = victimId and Players:GetPlayerByUserId(victimId)
			local victimRoot = victim and victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
			local victimPoint = victimRoot and (victimRoot.Position + Vector3.new(0, 0.6, 0))

			rig.startPart.Position = mouth
			rig.tongue.Enabled = false
			rig.laser.Enabled = false
			rig.tip.Transparency = 1

			if state == "aim" and victimPoint then
				-- láser fino que parpadea cada vez más rápido
				local u = math.clamp((serverNow - t) / dur, 0, 1)
				rig.endPart.Position = victimPoint
				rig.laser.Enabled = true
				rig.laser.Transparency = NumberSequence.new(0.35 + 0.3 * math.sin(serverNow * (10 + 30 * u)))
				rig.laser.Width0 = 0.07 + 0.09 * u
				rig.laser.Width1 = 0.07 + 0.09 * u
				if victim == player then
					locked = true
				end
			elseif state == "shot" then
				local u = math.clamp((serverNow - t) / math.max(dur, 0.05), 0, 1)
				local aim = model:GetAttribute("TongueAim") or mouth
				local tipPosition = mouth:Lerp(aim, u)
				rig.lastEnd = tipPosition
				rig.endPart.Position = tipPosition
				rig.tip.Position = tipPosition
				rig.tip.Transparency = 0
				rig.tongue.Enabled = true
				rig.tongue.CurveSize0 = math.sin(serverNow * 30) * 1.2 * (1 - u)
				rig.tongue.CurveSize1 = -math.sin(serverNow * 24) * 1.2 * (1 - u)
			elseif state == "hold" and victimPoint then
				rig.lastEnd = victimPoint
				rig.endPart.Position = victimPoint
				rig.tip.Position = victimPoint
				rig.tip.Transparency = 0
				rig.tongue.Enabled = true
				-- tensa, con un temblor ligero
				rig.tongue.CurveSize0 = math.sin(serverNow * 18) * 0.35
				rig.tongue.CurveSize1 = math.sin(serverNow * 15 + 1) * 0.35
			elseif state == "retract" then
				local u = math.clamp((serverNow - t) / RETRACT_TIME, 0, 1)
				local tipPosition = rig.lastEnd:Lerp(mouth, u * u)
				rig.endPart.Position = tipPosition
				rig.tip.Position = tipPosition
				rig.tip.Transparency = u >= 1 and 1 or 0
				rig.tongue.Enabled = u < 1
				rig.tongue.CurveSize0 = math.sin(serverNow * 30) * 1.5 * u
				rig.tongue.CurveSize1 = -math.sin(serverNow * 26) * 1.5 * u
			end
		end
	end
	if warning then
		warning.Enabled = locked
	end
end

function GrabberFx.start()
	warning = buildWarning()
	for _, model in CollectionService:GetTagged("ZombieRig") do
		task.spawn(register, model)
	end
	CollectionService:GetInstanceAddedSignal("ZombieRig"):Connect(function(model)
		-- el atributo Kind llega junto con el modelo; se espera un instante por si acaso
		task.defer(register, model)
		task.delay(1, register, model)
	end)
	RunService.RenderStepped:Connect(update)
end

return GrabberFx
