-- Controles táctiles (celular y tablet). El movimiento y el salto los pone Roblox (joystick dinámico a la izquierda); aquí van:
--   · botones de la derecha: DISPARO (mantener = automática; arrastrar sin soltar gira la cámara), APUNTAR (alterna), RECARGAR,
--     CORRER (alterna) y los botones de contexto E / F / G / H que solo aparecen cuando hacen algo;
--   · CANCELAR cuando se carga una granada, molotov o bengala; LISTO en el lobby;
--   · arriba a la derecha: vista (primera/tercera persona), ayuda y ajustes;
--   · la sensibilidad del jugador (SettingsPanel) escala el giro que ya hace Roblox al arrastrar el dedo por la pantalla.
-- Los botones llaman a las mismas funciones que las teclas (Shooting, ItemUse, Sprint, CameraController, TeamHud, GameHud), y
-- los prompts (revivir, caja, comprar, generador, furgoneta…) se activan con ProximityPrompt:InputHoldBegin/End.
-- Se ve solo en modo táctil (Controls.isTouch) y se apaga con una ventana abierta, de espectador o en los resultados.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local CameraController = require(script.Parent.CameraController)
local Controls = require(script.Parent.Controls)
local GameHud = require(script.Parent.GameHud)
local HelpPanel = require(script.Parent.HelpPanel)
local ItemUse = require(script.Parent.ItemUse)
local SettingsPanel = require(script.Parent.SettingsPanel)
local Shooting = require(script.Parent.Shooting)
local Spectator = require(script.Parent.Spectator)
local Sprint = require(script.Parent.Sprint)
local TeamHud = require(script.Parent.TeamHud)
local WeaponAnimator = require(script.Parent.WeaponAnimator)

local player = Players.LocalPlayer
local T = Config.Touch

local GOLD = Color3.fromRGB(246, 196, 70)
local DARK = Color3.fromRGB(14, 13, 13)
local GREY = Color3.fromRGB(96, 96, 100)
local RED = Color3.fromRGB(214, 56, 48)
local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)

-- Posición de cada botón: centro, en unidades que se escalan (x, y negativos = hacia la izquierda y arriba de la esquina
-- inferior derecha). El salto de Roblox queda en la esquina; todo lo demás se ordena a su alrededor.
local LAYOUT = {
	Fire = { x = -148, y = -58, size = 84 },
	Aim = { x = -60, y = -135, size = 54 },
	Reload = { x = -135, y = -140, size = 48 },
	Sprint = { x = -222, y = -55, size = 50 },
	Cancel = { x = -60, y = -205, size = 52 },
	KeyE = { x = -212, y = -140, size = 64 },
	KeyF = { x = -212, y = -212, size = 54 },
	Drop = { x = -282, y = -110, size = 54 },
	SelfRevive = { x = -282, y = -178, size = 60 },
}

local TouchControls = {}

local gui -- ScreenGui de los botones
local buttons = {} -- nombre -> { frame, label, sub, bar }
local scaleUnit = 1

-- Toques que se siguen mientras el dedo está abajo: clave (el toque) -> { onEnd, onMove }
local tracked = {}
local function trackKey(input)
	return input.UserInputType == Enum.UserInputType.Touch and input or "mouse"
end

local function track(frame, onBegin, onEnd, onMove)
	frame.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local key = trackKey(input)
		if tracked[key] then
			return
		end
		tracked[key] = { onEnd = onEnd, onMove = onMove }
		onBegin()
	end)
end

local function release(input)
	local key = trackKey(input)
	local entry = tracked[key]
	if entry then
		tracked[key] = nil
		if entry.onEnd then
			entry.onEnd()
		end
	end
end

-- Giro de cámara que sale de arrastrar el dedo sobre el botón de disparo (el resto de la pantalla lo gira Roblox)
local dragDX, dragDY = 0, 0
local function addDrag(delta)
	dragDX += delta.X
	dragDY += delta.Y
end

local function makeButton(name, text, color)
	local spec = LAYOUT[name]
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = DARK
	frame.BackgroundTransparency = 0.35
	frame.BorderSizePixel = 0
	frame.Active = true -- se come el toque: ni el joystick ni la cámara lo reciben
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or GREY
	stroke.Thickness = 2.5
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = OSWALD
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.24, 0)
	pad.PaddingBottom = UDim.new(0.24, 0)
	pad.PaddingLeft = UDim.new(0.14, 0)
	pad.PaddingRight = UDim.new(0.14, 0)
	pad.Parent = label

	-- Barra de "mantener" para los botones de contexto
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.fromScale(0.15, 0.94)
	bar.Size = UDim2.fromScale(0, 0.07)
	bar.BackgroundColor3 = GOLD
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = frame

	local button = { frame = frame, label = label, stroke = stroke, bar = bar, spec = spec, baseColor = color or GREY }
	buttons[name] = button
	return button
end

local function setLit(button, lit)
	button.stroke.Color = lit and GOLD or button.baseColor
	button.frame.BackgroundTransparency = lit and 0.15 or 0.35
end

local function layout()
	local viewport = workspace.CurrentCamera.ViewportSize
	-- el botón de salto de Roblox mide 70 en pantallas pequeñas y 120 en las grandes
	scaleUnit = (math.min(viewport.X, viewport.Y) < 500 and 70 or 120) / 70
	for _, button in buttons do
		local spec = button.spec
		button.frame.Size = UDim2.fromOffset(spec.size * scaleUnit, spec.size * scaleUnit)
		button.frame.Position = UDim2.new(1, spec.x * scaleUnit, 1, spec.y * scaleUnit)
	end
end

-- Contexto: prompts de revivir, caja, comprar, generador, furgoneta… -------------------------------------------------------

local shown = {} -- prompts que Roblox muestra ahora mismo

local function bestPrompt(keyCode)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for prompt in shown do
		local part = prompt.Parent
		if prompt.Enabled and prompt.KeyboardKeyCode == keyCode and part and part:IsA("BasePart") and prompt:IsDescendantOf(workspace) then
			local distance = (part.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = prompt, distance
			end
		end
	end
	return best
end

-- Botón de contexto ligado a una tecla de ProximityPrompt
local function bindPromptButton(name, keyCode, keyText)
	local button = makeButton(name, keyText, GOLD)
	local current = nil -- prompt asignado ahora
	local held = nil -- prompt que se mantiene pulsado

	local function stopHold()
		if held then
			if held.Parent then
				held:InputHoldEnd()
			end
			held = nil
		end
		button.bar.Visible = false
		setLit(button, false)
	end

	track(button.frame, function()
		if not current then
			return
		end
		held = current
		held:InputHoldBegin()
		setLit(button, true)
		if held.HoldDuration > 0 then
			button.bar.Size = UDim2.fromScale(0, 0.07)
			button.bar.Visible = true
			TweenService:Create(button.bar, TweenInfo.new(held.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0.7, 0.07) }):Play()
		end
	end, stopHold)

	button.update = function()
		current = bestPrompt(keyCode)
		if held and (held ~= current or not held.Enabled) then
			stopHold()
		end
		if current then
			local action = current.ActionText ~= "" and current.ActionText or keyText
			local shown = `{keyText}\n{Lang.upper(Lang.tr(action))}`
			if button.label.Text ~= shown then
				button.label.Text = shown
			end
		end
		button.visible = current ~= nil
	end
	button.stop = stopHold
end

-- Cámara: sensibilidad y giro con el dedo ----------------------------------------------------------------------------------

local function lookAngles(look)
	return math.atan2(-look.X, -look.Z), math.asin(math.clamp(look.Y, -1, 1))
end

local function lookVector(yaw, pitch)
	local cosPitch = math.cos(pitch)
	return Vector3.new(-math.sin(yaw) * cosPitch, math.sin(pitch), -math.cos(yaw) * cosPitch)
end

local function wrap(angle)
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

local lastYaw, lastPitch = nil, nil -- hacia dónde miraba la cámara al terminar nuestro paso del cuadro anterior

-- Se ejecuta justo ANTES de que Roblox mueva la cámara. Lo que la cámara giró desde el cuadro anterior (el dedo arrastrando por la
-- pantalla) se mide y se completa hasta la sensibilidad elegida; el arrastre sobre el botón de disparo se suma aquí.
local function cameraStep()
	local camera = workspace.CurrentCamera
	if not Controls.isTouch() or camera.CameraType ~= Enum.CameraType.Custom or player:GetAttribute("UiOpen") then
		lastYaw, lastPitch = nil, nil
		dragDX, dragDY = 0, 0
		return
	end

	local pure = WeaponAnimator.cameraCFrame() -- sin la sacudida del retroceso
	local yaw, pitch = lookAngles(pure.LookVector)
	local factor = Controls.getSensitivity() * (Controls.isAiming() and T.AimLookFactor or 1)

	local newYaw, newPitch = yaw, pitch
	if lastYaw then
		local dYaw, dPitch = wrap(yaw - lastYaw), pitch - lastPitch
		-- un salto enorme es un cambio de cámara ajeno (reaparecer, espectador…), no un dedo
		if math.abs(dYaw) < 1 and math.abs(dPitch) < 1 then
			newYaw += dYaw * (factor - 1)
			newPitch += dPitch * (factor - 1)
		end
	end

	if dragDX ~= 0 or dragDY ~= 0 then
		local radians = math.rad(T.LookDegPerPixel) * factor
		newYaw -= dragDX * radians
		newPitch -= dragDY * radians
		dragDX, dragDY = 0, 0
	end

	local maxPitch = math.rad(T.MaxPitch)
	newPitch = math.clamp(newPitch, -maxPitch, maxPitch)
	if newYaw ~= yaw or newPitch ~= pitch then
		local position = camera.CFrame.Position
		camera.CFrame = CFrame.lookAt(position, position + lookVector(newYaw, newPitch))
	end
	lastYaw, lastPitch = newYaw, newPitch
end

-- Construcción ---------------------------------------------------------------------------------------------------------------

local function smallButton(index, name, text)
	local f = Instance.new("TextButton")
	f.Name = name
	f.AnchorPoint = Vector2.new(1, 0)
	f.Size = UDim2.fromOffset(40, 40)
	f.Position = UDim2.new(1, -(12 + (index - 1) * 46), 0, 12)
	f.BackgroundColor3 = DARK
	f.BackgroundTransparency = 0.35
	f.BorderSizePixel = 0
	f.AutoButtonColor = false
	f.FontFace = OSWALD
	f.TextSize = 22
	f.TextColor3 = Color3.new(1, 1, 1)
	f.Text = text
	f.Parent = gui
	Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = GREY
	stroke.Thickness = 2
	stroke.Parent = f
	return f
end

function TouchControls.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "TouchControls"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.DisplayOrder = 6
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Disparo -------------------------------------------------------------------------------------------------------
	local fire = makeButton("Fire", "FIRE", RED)
	track(fire.frame, function()
		setLit(fire, true)
		Controls.firing = true
		if not ItemUse.press() then
			Shooting.setFiring(true)
		end
	end, function()
		setLit(fire, false)
		Controls.firing = false
		ItemUse.release()
		Shooting.setFiring(false)
	end, addDrag)

	-- Apuntar (alterna)
	local aim = makeButton("Aim", "AIM")
	track(aim.frame, function()
		Controls.aim = not Controls.aim
		CameraController.setAiming(Controls.aim)
		setLit(aim, Controls.aim)
	end)

	local reload = makeButton("Reload", "RELOAD")
	track(reload.frame, function()
		setLit(reload, true)
		Shooting.reload()
	end, function()
		setLit(reload, false)
	end)

	-- Correr (alterna): se cancela solo al disparar, apuntar o recargar y vuelve al terminar, como con Shift
	local sprint = makeButton("Sprint", "SPRINT")
	track(sprint.frame, function()
		Sprint.setHeld(not Sprint.isHeld())
	end)

	local cancel = makeButton("Cancel", "CANCEL", GOLD)
	track(cancel.frame, function()
		ItemUse.cancel()
	end)

	bindPromptButton("KeyE", Enum.KeyCode.E, "E")
	bindPromptButton("KeyF", Enum.KeyCode.F, "F")

	local drop = makeButton("Drop", "DROP", GOLD)
	track(drop.frame, function()
		TeamHud.drop()
	end)

	local selfRevive = makeButton("SelfRevive", "GET UP", GOLD)
	local selfReviveHeld = false
	track(selfRevive.frame, function()
		selfReviveHeld = true
		setLit(selfRevive, true)
		TeamHud.beginSelfRevive()
	end, function()
		selfReviveHeld = false
		setLit(selfRevive, false)
		TeamHud.endSelfRevive()
	end)

	-- Arriba a la derecha: vista, ayuda, ajustes
	local view = smallButton(1, "View", "👁")
	view.Activated:Connect(function()
		CameraController.toggleView()
	end)
	local help = smallButton(2, "Help", "?")
	help.Activated:Connect(function()
		HelpPanel.toggle()
	end)
	local settings = smallButton(3, "Settings", "⚙")
	settings.Activated:Connect(function()
		SettingsPanel.toggle()
	end)

	-- Listo en el lobby (abajo al centro, sobre el inventario)
	local readyShown = nil
	local ready = Instance.new("TextButton")
	ready.Name = "Ready"
	ready.AnchorPoint = Vector2.new(0.5, 1)
	ready.Position = UDim2.new(0.5, 0, 1, -64)
	ready.Size = UDim2.fromOffset(150, 44)
	ready.BackgroundColor3 = DARK
	ready.BackgroundTransparency = 0.25
	ready.BorderSizePixel = 0
	ready.AutoButtonColor = false
	ready.FontFace = OSWALD
	ready.TextSize = 24
	ready.TextColor3 = Color3.new(1, 1, 1)
	ready.Visible = false
	ready.Parent = gui
	Instance.new("UICorner", ready).CornerRadius = UDim.new(0, 10)
	local readyStroke = Instance.new("UIStroke")
	readyStroke.Color = GOLD
	readyStroke.Thickness = 2
	readyStroke.Parent = ready
	ready.Activated:Connect(function()
		GameHud.ready()
	end)

	layout()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)

	-- Entrada ---------------------------------------------------------------------------------------------------------
	UserInputService.TouchMoved:Connect(function(touch)
		local entry = tracked[touch]
		if entry and entry.onMove then
			entry.onMove(touch.Delta)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local entry = tracked.mouse -- dispositivo híbrido: botón pulsado con el ratón
			if entry and entry.onMove then
				entry.onMove(input.Delta)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			release(input)
		end
	end)

	ProximityPromptService.PromptShown:Connect(function(prompt)
		shown[prompt] = true
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		shown[prompt] = nil
	end)

	RunService:BindToRenderStep("TouchCamera", Enum.RenderPriority.Camera.Value - 1, cameraStep)

	-- Qué botones se ven ----------------------------------------------------------------------------------------------
	local function refresh()
		local touch = Controls.isTouch()
		local stage = workspace:GetAttribute("Stage") or "Lobby"
		local playing = touch and not player:GetAttribute("UiOpen") and not Spectator.isActive() and stage ~= "Result"
		gui.Enabled = touch
		if not touch then
			return
		end

		local itemInHand = player:GetAttribute("ItemReady")
		for _, name in { "Fire", "Aim", "Reload", "Sprint" } do
			buttons[name].frame.Visible = playing
		end
		-- con un objeto en la mano el botón de disparo lo usa; recargar y apuntar se quedan para el arma
		local fireText = itemInHand and (itemInHand == "Medkit" and "HEAL" or (itemInHand == "Bandage" and "BANDAGE" or "THROW")) or "FIRE"
		if fire.fireText ~= fireText then
			fire.fireText = fireText
			fire.label.Text = fireText
		end
		setLit(sprint, Sprint.isHeld())
		reload.frame.Visible = playing and itemInHand == nil
		aim.frame.Visible = playing and itemInHand == nil
		if itemInHand ~= nil and Controls.aim then
			Controls.aim = false
			CameraController.setAiming(false)
			setLit(aim, false)
		end
		cancel.frame.Visible = playing and ItemUse.isCharging()

		for _, name in { "KeyE", "KeyF" } do
			local button = buttons[name]
			button.update()
			button.frame.Visible = playing and button.visible == true
			if not button.frame.Visible then
				button.stop()
			end
		end
		drop.frame.Visible = playing and player:GetAttribute("Carrying") ~= nil
		selfRevive.frame.Visible = playing and TeamHud.canSelfRevive()
		if not selfRevive.frame.Visible and selfReviveHeld then
			selfReviveHeld = false
			setLit(selfRevive, false)
			TeamHud.endSelfRevive()
		end

		local inLobby = stage == "Lobby" and not Spectator.isActive() and not player:GetAttribute("UiOpen")
		ready.Visible = inLobby
		local readyText = player:GetAttribute("Ready") and "✔ READY" or "I'M READY"
		if readyShown ~= readyText then
			readyShown = readyText
			ready.Text = readyText
		end
		readyStroke.Color = player:GetAttribute("Ready") and Color3.fromRGB(110, 210, 110) or GOLD
	end

	RunService.Heartbeat:Connect(refresh)
	Controls.touchChanged:Connect(function(touch)
		if not touch then
			Controls.aim = false
			Controls.firing = false
			CameraController.setAiming(false)
		end
	end)
end

return TouchControls
