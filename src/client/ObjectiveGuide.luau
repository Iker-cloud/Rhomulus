-- Guía de objetivo para no perderse: una columna de luz en el mundo (se ve desde lejos y por encima de las paredes),
-- un cartel con el nombre y la distancia sobre el objetivo y, cuando el objetivo no está en pantalla, una flecha grande
-- en el borde que apunta hacia él. El servidor publica la posición (Workspace.ObjectivePos / ObjectiveName, ver GameState).
-- Hay dos guías con el mismo dibujo: la del objetivo de la orden (amarilla: punto seguro, generador, van…) y la de la TIENDA de la zona
-- (Workspace.ShopPos, de otro color), para que se sepa dónde comprar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local G = Config.Guide
local player = Players.LocalPlayer

local ObjectiveGuide = {}

local italic = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)

-- Crea una guía. `options`: posAttr = atributo de Workspace con la posición, nameAttr = atributo con el nombre (o fixedName), color,
-- order = orden de dibujo de la flecha.
local function createGuide(options)
	local color = options.color

	-- Columna de luz y cartel en el mundo
	local beacon = Instance.new("Part")
	beacon.Name = options.beaconName
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.CanTouch = false
	beacon.CastShadow = false
	beacon.Material = Enum.Material.Neon
	beacon.Color = color
	beacon.Transparency = G.ShowBeam and 0.35 or 1 -- sin columna: la pieza queda invisible y solo sirve de ancla del cartel
	beacon.Size = Vector3.new(G.BeaconWidth, G.BeaconHeight, G.BeaconWidth)

	if G.ShowBeam then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 30
		light.Brightness = 2
		light.Parent = beacon
	end

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(240, 70)
	sign.StudsOffsetWorldSpace = Vector3.new(0, -G.BeaconHeight / 2 + (options.signHeight or 16), 0) -- el cartel va cerca del suelo del objetivo
	sign.AlwaysOnTop = true
	sign.MaxDistance = 2000
	sign.ResetOnSpawn = false
	sign.Adornee = beacon
	sign.Parent = beacon

	local function label(parent, y, height, size)
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromOffset(0, y)
		text.Size = UDim2.new(1, 0, 0, height)
		text.FontFace = italic
		text.TextSize = size
		text.TextColor3 = color
		text.TextStrokeTransparency = 0.2
		text.Parent = parent
		return text
	end
	local signName = label(sign, 0, 36, 28)
	local signDistance = label(sign, 36, 28, 22)
	signDistance.TextColor3 = Color3.new(1, 1, 1)

	-- Flecha en el borde de la pantalla
	local gui = Instance.new("ScreenGui")
	gui.Name = options.guiName
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- las coordenadas son las de la pantalla completa
	gui.DisplayOrder = options.order
	gui.Parent = player:WaitForChild("PlayerGui")

	local arrow = Instance.new("Frame")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(G.ArrowSize, G.ArrowSize + 28)
	arrow.BackgroundTransparency = 1
	arrow.Visible = false
	arrow.Parent = gui

	-- La flecha gira sola dentro de un contenedor; el texto de la distancia no gira
	local pointer = Instance.new("TextLabel")
	pointer.AnchorPoint = Vector2.new(0.5, 0.5)
	pointer.Position = UDim2.fromOffset(G.ArrowSize / 2, G.ArrowSize / 2)
	pointer.Size = UDim2.fromOffset(G.ArrowSize, G.ArrowSize)
	pointer.BackgroundTransparency = 1
	pointer.Font = Enum.Font.GothamBlack
	pointer.Text = "▲"
	pointer.TextSize = G.ArrowSize
	pointer.TextColor3 = color
	pointer.TextStrokeTransparency = 0
	pointer.Parent = arrow

	local distance = Instance.new("TextLabel")
	distance.BackgroundTransparency = 1
	distance.Position = UDim2.fromOffset(-30, G.ArrowSize)
	distance.Size = UDim2.new(1, 60, 0, 28)
	distance.FontFace = italic
	distance.TextSize = 22
	distance.TextColor3 = Color3.new(1, 1, 1)
	distance.TextStrokeTransparency = 0.2
	distance.Parent = arrow

	local currentPosition, currentName

	local function refresh()
		local position = workspace:GetAttribute(options.posAttr)
		local name = options.fixedName or workspace:GetAttribute(options.nameAttr)
		if position ~= currentPosition or name ~= currentName then
			currentPosition, currentName = position, name
			if position then
				beacon.CFrame = CFrame.new(position.X, G.BeaconHeight / 2, position.Z)
				beacon.Parent = workspace
				signName.Text = name or ""
			else
				beacon.Parent = nil
			end
		end
	end
	workspace:GetAttributeChangedSignal(options.posAttr):Connect(refresh)
	if options.nameAttr then
		workspace:GetAttributeChangedSignal(options.nameAttr):Connect(refresh)
	end
	refresh()

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not (currentPosition and camera) then
			arrow.Visible = false
			return
		end

		local meters = math.floor((currentPosition - camera.CFrame.Position).Magnitude / G.StudsPerMeter + 0.5)
		signDistance.Text = `{meters} m`
		distance.Text = `{currentName} · {meters} m`

		local viewport = camera.ViewportSize
		local target = currentPosition + Vector3.new(0, 6, 0)
		local screen, inFront = camera:WorldToViewportPoint(target)
		local center = viewport / 2
		local margin = G.EdgeMargin
		local visibleOnScreen = inFront
			and math.abs(screen.X - center.X) < viewport.X / 2 - margin
			and math.abs(screen.Y - center.Y) < viewport.Y / 2 - margin
		if visibleOnScreen then
			arrow.Visible = false
			return
		end

		-- Dirección hacia el objetivo vista desde la cámara (derecha = +X, abajo = -Y); sirve también si está detrás
		local relative = camera.CFrame:PointToObjectSpace(target)
		local offset = Vector2.new(relative.X, -relative.Y)

		if offset.Magnitude < 1 then
			offset = Vector2.new(0, 1) -- justo detrás: apunta hacia abajo
		end
		local scale = math.min(
			(viewport.X / 2 - margin) / math.max(math.abs(offset.X), 1e-3),
			(viewport.Y / 2 - margin - 14) / math.max(math.abs(offset.Y), 1e-3)
		)
		local position = center + offset * scale
		arrow.Position = UDim2.fromOffset(position.X, position.Y)
		pointer.Rotation = math.deg(math.atan2(offset.Y, offset.X)) + 90 -- "▲" apunta hacia arriba
		arrow.Visible = true
	end)
end

function ObjectiveGuide.start()
	if not G.Enabled then
		return
	end
	createGuide({ beaconName = "ObjectiveBeacon", guiName = "ObjectiveGuide", posAttr = "ObjectivePos", nameAttr = "ObjectiveName", color = G.Color, order = 10 })
	createGuide({ beaconName = "ShopBeacon", guiName = "ShopGuide", posAttr = "ShopPos", fixedName = "TIENDA", color = G.ShopColor, order = 9, signHeight = 24 })
end

return ObjectiveGuide
