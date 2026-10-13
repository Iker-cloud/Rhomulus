-- Modo espectador: al morir en una partida de 2 o más jugadores, la cámara pasa a seguir a un compañero que siga en pie (o caído)
-- hasta que reaparezca en el siguiente punto seguro. Se cambia de compañero con A / D o las flechas, o pulsando su ficha abajo (salen
-- todos). La cámara va detrás del hombro del compañero y mira hacia donde él apunta (el servidor publica AimPitch en su personaje).
-- Si el compañero queda muy lejos del anterior, la pantalla hace un fundido a negro en vez de cruzar todo el mapa.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(script.Parent.Icons)

local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(246, 196, 70)
local RED = Color3.fromRGB(226, 66, 54)
local ORANGE = Color3.fromRGB(255, 140, 40)
local GREEN = Color3.fromRGB(110, 210, 120)
local DARK = Color3.fromRGB(14, 13, 13)
local GREY = Color3.fromRGB(150, 146, 140)
local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)

local DISTANCE = 9 -- studs detrás del compañero
local HEIGHT = 1.4 -- la cámara sobre el punto que mira
local SIDE = 1.7 -- desplazamiento al hombro derecho
local FAR_SWITCH = 70 -- si la cámara tiene que viajar más que esto al cambiar, se hace un fundido
local OFF_STAGES = { Lobby = true, Vote = true, Result = true } -- fuera de la partida no se espectea

local Spectator = {}

local active = false
local target = nil -- el compañero que se mira
local camPosition = nil
local smoothDirection = Vector3.new(0, 0, -1)
local smoothPitch = 0
local ui = nil
local chips = {} -- [Player] = ficha

local function stateOf(p)
	return p:GetAttribute("State") or "Normal"
end

-- Compañeros que se pueden mirar: con personaje y vida (en pie o caídos), en orden estable
local function candidates()
	local list = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and stateOf(other) ~= "Dead" then
			local character = other.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") then
				table.insert(list, other)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

local function shouldSpectate()
	if stateOf(player) ~= "Dead" or #Players:GetPlayers() < 2 then
		return false
	end
	if OFF_STAGES[workspace:GetAttribute("Stage") or "Lobby"] then
		return false
	end
	return #candidates() > 0
end

-- UI --------------------------------------------------------------------------------------------------------------------------

local function label(parent, text, size, position, textSize, color, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.FontFace = OSWALD
	l.TextSize = textSize
	l.TextColor3 = color
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Text = text
	l.Parent = parent
	return l
end

local function keycap(parent, text, order)
	local cap = Instance.new("Frame")
	cap.Size = UDim2.fromOffset(46, 34)
	cap.BackgroundColor3 = DARK
	cap.BackgroundTransparency = 0.2
	cap.BorderSizePixel = 0
	cap.LayoutOrder = order
	cap.Parent = parent
	Instance.new("UICorner", cap).CornerRadius = UDim.new(0, 6)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 86, 82)
	stroke.Thickness = 1.5
	stroke.Parent = cap
	label(cap, text, UDim2.fromScale(1, 1), UDim2.new(), 17, Color3.fromRGB(225, 220, 210))
	return cap
end

local function buildUi()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Spectator"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Viñeta suave en los bordes para que se note que ya no es tu cámara
	local vignette = Instance.new("Frame")
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundTransparency = 1
	vignette.Parent = gui
	for _, top in { true, false } do
		local band = Instance.new("Frame")
		band.AnchorPoint = Vector2.new(0, top and 0 or 1)
		band.Position = UDim2.fromScale(0, top and 0 or 1)
		band.Size = UDim2.new(1, 0, 0, 120)
		band.BackgroundColor3 = Color3.new(0, 0, 0)
		band.BorderSizePixel = 0
		band.Parent = vignette
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = top and 90 or -90
		gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		gradient.Parent = band
	end

	-- Placa de arriba: ESPECTANDO + nombre + estado
	local card = Instance.new("CanvasGroup")
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 18)
	card.Size = UDim2.fromOffset(380, 82)
	card.BackgroundColor3 = DARK
	card.BackgroundTransparency = 0.12
	card.BorderSizePixel = 0
	card.Parent = gui
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 4)
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(70, 66, 62)
	cardStroke.Parent = card
	Icons.tape(card, UDim2.new(1, 0, 0, 5), UDim2.fromOffset(0, 0), RED, Color3.fromRGB(20, 12, 12))
	local eyebrow = label(card, "E S P E C T A N D O", UDim2.new(1, 0, 0, 16), UDim2.fromOffset(0, 11), 13, GREY)
	local name = label(card, "", UDim2.new(1, -24, 0, 36), UDim2.fromOffset(12, 26), 32, Color3.new(1, 1, 1))
	local status = label(card, "", UDim2.new(1, 0, 0, 16), UDim2.fromOffset(0, 62), 15, GREEN)

	-- Franja de abajo: tecla ◄, las fichas de todos los compañeros, tecla ►
	local row = Instance.new("Frame")
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.new(0.5, 0, 1, -28)
	row.Size = UDim2.fromOffset(0, 58)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.BackgroundTransparency = 1
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row
	keycap(row, "◄ A", 0)
	keycap(row, "D ►", 1000)

	local hint = label(gui, "Reaparecerás en el siguiente punto seguro", UDim2.fromOffset(420, 18), UDim2.new(0.5, -210, 1, -106), 15, Color3.fromRGB(190, 185, 176))
	hint.TextStrokeTransparency = 0.6

	-- Fundido a negro para los cambios largos
	local fade = Instance.new("Frame")
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 1
	fade.BorderSizePixel = 0
	fade.ZIndex = 50
	fade.Active = false
	fade.Parent = gui

	return { gui = gui, card = card, eyebrow = eyebrow, name = name, status = status, row = row, hint = hint, fade = fade, cardScale = Instance.new("UIScale", card) }
end

local function makeChip(other, order)
	local chip = Instance.new("TextButton")
	chip.AutoButtonColor = false
	chip.Text = ""
	chip.Size = UDim2.fromOffset(150, 52)
	chip.BackgroundColor3 = DARK
	chip.BackgroundTransparency = 0.18
	chip.BorderSizePixel = 0
	chip.LayoutOrder = order
	chip.Parent = ui.row
	Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 6)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(70, 66, 62)
	stroke.Parent = chip
	local scale = Instance.new("UIScale", chip)

	local avatar = Instance.new("ImageLabel")
	avatar.Position = UDim2.fromOffset(8, 8)
	avatar.Size = UDim2.fromOffset(36, 36)
	avatar.BackgroundColor3 = Color3.fromRGB(40, 38, 36)
	avatar.BorderSizePixel = 0
	avatar.Parent = chip
	Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(other.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and avatar.Parent then
			avatar.Image = image
		end
	end)

	local nameLabel = label(chip, other.DisplayName, UDim2.fromOffset(96, 20), UDim2.fromOffset(50, 7), 17, Color3.new(1, 1, 1), Enum.TextXAlignment.Left)
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	local stateLabel = label(chip, "", UDim2.fromOffset(96, 14), UDim2.fromOffset(50, 26), 12, GREEN, Enum.TextXAlignment.Left)
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 50, 1, -11)
	back.Size = UDim2.new(1, -60, 0, 4)
	back.BackgroundColor3 = Color3.fromRGB(52, 48, 46)
	back.BorderSizePixel = 0
	back.Parent = chip
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = RED
	fill.BorderSizePixel = 0
	fill.Parent = back

	chip.Activated:Connect(function()
		if active then
			Spectator.select(other)
		end
	end)
	return { frame = chip, stroke = stroke, scale = scale, name = nameLabel, state = stateLabel, fill = fill }
end

-- Fichas y datos: se crean las que faltan, se quitan las de quien ya no se puede mirar y se actualizan vida y estado
local function refreshUi(list)
	local present = {}
	for index, other in list do
		present[other] = true
		local chip = chips[other]
		if not chip then
			chip = makeChip(other, index)
			chips[other] = chip
		end
		chip.frame.LayoutOrder = index
		local humanoid = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
		local ratio = humanoid and humanoid.Health / humanoid.MaxHealth or 0
		local downed = stateOf(other) == "Downed"
		local selected = other == target
		chip.fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		chip.fill.BackgroundColor3 = downed and ORANGE or RED
		chip.state.Text = downed and "CAÍDO" or "EN PIE"
		chip.state.TextColor3 = downed and ORANGE or GREEN
		chip.stroke.Color = selected and GOLD or Color3.fromRGB(70, 66, 62)
		chip.frame.BackgroundTransparency = selected and 0.05 or 0.3
		local goal = selected and 1.07 or 0.94
		chip.scale.Scale += (goal - chip.scale.Scale) * 0.25
	end
	for other, chip in chips do
		if not present[other] then
			chip.frame:Destroy()
			chips[other] = nil
		end
	end

	if target and present[target] then
		local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		local downed = stateOf(target) == "Downed"
		ui.name.Text = string.upper(target.DisplayName)
		if downed then
			local bleedEnd = target:GetAttribute("BleedEnd")
			local left = bleedEnd and math.max(0, bleedEnd - workspace:GetServerTimeNow()) or 0
			ui.status.Text = `CAÍDO · SE DESANGRA EN {math.ceil(left)} s`
			ui.status.TextColor3 = ORANGE
		else
			local percent = humanoid and math.floor(humanoid.Health / humanoid.MaxHealth * 100 + 0.5) or 0
			ui.status.Text = `EN PIE · VIDA {percent}%`
			ui.status.TextColor3 = GREEN
		end
	end
	ui.eyebrow.Text = #list > 1 and "E S P E C T A N D O" or "E S P E C T A N D O  ·  ÚNICO COMPAÑERO"
end

-- Cámara ----------------------------------------------------------------------------------------------------------------------

local function viewParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignored = { workspace.CurrentCamera }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignored, other.Character)
		end
	end
	local zombies = workspace:FindFirstChild("Zombies")
	if zombies then
		table.insert(ignored, zombies)
	end
	params.FilterDescendantsInstances = ignored
	return params
end

-- Dónde debería estar la cámara y qué mira para el compañero `who`, o nil si no tiene personaje
local function viewOf(who, dt)
	local character = who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or smoothDirection
	smoothDirection = smoothDirection:Lerp(flat, 1 - math.exp(-7 * dt))
	if smoothDirection.Magnitude < 0.05 then
		smoothDirection = flat
	end
	smoothDirection = smoothDirection.Unit
	smoothPitch += (math.clamp(character:GetAttribute("AimPitch") or 0, -0.6, 0.6) - smoothPitch) * (1 - math.exp(-6 * dt))

	local focus = root.Position + Vector3.new(0, 2.6, 0)
	local right = smoothDirection:Cross(Vector3.yAxis)
	local desired = focus - smoothDirection * DISTANCE + right * SIDE + Vector3.new(0, HEIGHT, 0)
	-- La pared no tapa la vista: se acerca al compañero hasta donde llega el rayo
	local hit = workspace:Raycast(focus, desired - focus, viewParams())
	if hit then
		desired = hit.Position + (focus - desired).Unit * 0.5
	end
	local lookPoint = focus + smoothDirection * 40 + Vector3.new(0, math.tan(smoothPitch) * 40, 0)
	return desired, lookPoint, root.Position
end

local function fadeSwitch(apply)
	local tween = TweenService:Create(ui.fade, TweenInfo.new(0.18), { BackgroundTransparency = 0 })
	tween:Play()
	tween.Completed:Wait()
	apply()
	TweenService:Create(ui.fade, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
end

-- Cambia de compañero. Con `instant` no hace el fundido.
function Spectator.select(other)
	if not active or other == target then
		return
	end
	local previous = target
	target = other
	local desired = viewOf(other, 1 / 60)
	if previous and desired and camPosition and (desired - camPosition).Magnitude > FAR_SWITCH then
		task.spawn(fadeSwitch, function()
			camPosition = desired
		end)
	end
end

local function step(offset)
	local list = candidates()
	if #list == 0 then
		return
	end
	local index = table.find(list, target) or 0
	local nextIndex = ((index - 1 + offset) % #list) + 1
	Spectator.select(list[nextIndex])
end

local function enter()
	active = true
	local list = candidates()
	-- Empieza con el compañero más cerca de donde caíste
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	target = list[1]
	if root then
		local best = math.huge
		for _, other in list do
			local r = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			local distance = r and (r.Position - root.Position).Magnitude or math.huge
			if distance < best then
				best, target = distance, other
			end
		end
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Config.Camera.NormalFov
	camPosition = camera.CFrame.Position
	smoothDirection = Vector3.new(0, 0, -1)
	smoothPitch = 0
	ui.gui.Enabled = true
	ui.cardScale.Scale = 0.85
	TweenService:Create(ui.cardScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function exit()
	active = false
	target = nil
	ui.gui.Enabled = false
	ui.fade.BackgroundTransparency = 1
	for other, chip in chips do
		chip.frame:Destroy()
		chips[other] = nil
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

function Spectator.isActive()
	return active
end

function Spectator.start()
	ui = buildUi()

	UserInputService.InputBegan:Connect(function(input, processed)
		if not active or processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.A then
			step(-1)
		elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.D then
			step(1)
		end
	end)

	RunService:BindToRenderStep("Spectator", Enum.RenderPriority.Camera.Value + 2, function(dt)
		local should = shouldSpectate()
		if should and not active then
			enter()
		elseif not should and active then
			-- Con compañeros sin vida un instante (cambian de estado) no se sale: solo al reaparecer o al acabar la ronda
			if stateOf(player) ~= "Dead" or OFF_STAGES[workspace:GetAttribute("Stage") or "Lobby"] or #Players:GetPlayers() < 2 then
				exit()
			end
		end
		if not active then
			return
		end

		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true

		local list = candidates()
		-- Si el compañero que se mira ya no se puede, pasa al siguiente
		if not target or not table.find(list, target) then
			if #list > 0 then
				target = nil
				Spectator.select(list[1])
				target = list[1]
			end
		end
		refreshUi(list)

		if target then
			local desired, lookPoint = viewOf(target, dt)
			if desired then
				camPosition = camPosition:Lerp(desired, 1 - math.exp(-9 * dt))
				workspace.CurrentCamera.CFrame = CFrame.lookAt(camPosition, lookPoint)
			end
		end
	end)
end

return Spectator
