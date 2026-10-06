-- Munición junto a la mira. Cada arma tiene su propio estilo (Config.Weapons.X.AmmoStyle):
--   Ring     = anillo de balas alrededor de la mira (se rellena en sentido horario al recargar)
--   Magazine = cargador transparente (cae el vacío y sube uno lleno)
--   Shells   = fila de casquillos bajo la mira + cinta de recarga que avanza
--   Drum     = tambor que gira una recámara por disparo y da una vuelta al recargar
-- El número de balas queda siempre visible; la recarga se anima en la plantilla, no encima del número.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(230, 170, 60)
local BEIGE = Color3.fromRGB(205, 195, 180)
local DARK = Color3.fromRGB(22, 22, 22)
local LOW = Color3.fromRGB(255, 90, 70)
local OFF = 0.85 -- transparencia de una bala gastada

local AmmoHud = {}

local function frame(parent, size, position, color, anchor)
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor or Vector2.zero
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function round(f, radius)
	Instance.new("UICorner", f).CornerRadius = radius or UDim.new(1, 0)
end

local function text(parent, position, size, textSize, font)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = font
	label.TextSize = textSize
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

-- Número grande de balas y nombre/reserva pequeños
local function readout(parent, numberPosition, namePosition)
	local number = text(parent, numberPosition, UDim2.fromOffset(90, 30), 28, Enum.Font.GothamBlack)
	local scale = Instance.new("UIScale")
	scale.Parent = number
	local name = text(parent, namePosition, UDim2.fromOffset(160, 14), 13, Enum.Font.GothamMedium)
	name.TextTransparency = 0.15
	return number, name, scale
end

-- Contenedor sin tamaño centrado en la mira: sus hijos se colocan con offsets desde el centro
local function centered(gui)
	local root = frame(gui, UDim2.fromOffset(0, 0), UDim2.fromScale(0.5, 0.5), DARK)
	root.BackgroundTransparency = 1
	return root
end

local builders = {}

function builders.Ring(gui)
	local root = centered(gui)
	local s = { root = root, segments = {} }
	local radius = 26
	for i = 1, 12 do
		local angle = (i - 1) / 12 * math.pi * 2
		local tick = frame(root, UDim2.fromOffset(3, 10), UDim2.fromOffset(math.sin(angle) * radius, -math.cos(angle) * radius), GOLD, Vector2.new(0.5, 0.5))
		tick.Rotation = math.deg(angle)
		round(tick)
		s.segments[i] = tick
	end
	s.number, s.name, s.scale = readout(root, UDim2.fromOffset(32, 0), UDim2.fromOffset(34, 30))
	return s
end

function builders.Magazine(gui)
	local root = centered(gui)
	local s = { root = root, segments = {} }

	local mover = Instance.new("CanvasGroup")
	mover.Position = UDim2.fromOffset(42, -32)
	mover.Size = UDim2.fromOffset(24, 64)
	mover.BackgroundTransparency = 1
	mover.Parent = root

	local outline = frame(mover, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), DARK)
	outline.BackgroundTransparency = 1
	round(outline, UDim.new(0, 6))
	local stroke = Instance.new("UIStroke")
	stroke.Color = BEIGE
	stroke.Thickness = 2
	stroke.Parent = outline

	for i = 1, 12 do
		local seg = frame(mover, UDim2.fromOffset(14, 3), UDim2.fromOffset(5, 64 - 5 - 4.5 * i), GOLD)
		round(seg, UDim.new(0, 2))
		s.segments[i] = seg
	end

	s.number, s.name, s.scale = readout(root, UDim2.fromOffset(78, -26), UDim2.fromOffset(80, 6))

	function s.onReloadStart(duration, alive)
		-- Cae el cargador vacío y sube uno nuevo
		TweenService:Create(mover, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromOffset(42, 14),
			GroupTransparency = 1,
		}):Play()
		task.delay(0.25, function()
			if alive() then
				mover.Position = UDim2.fromOffset(42, 40)
				mover.GroupTransparency = 0
				TweenService:Create(mover, TweenInfo.new(math.max(0.1, duration - 0.25), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.fromOffset(42, -32),
				}):Play()
			end
		end)
	end
	function s.onReloadEnd()
		mover.Position = UDim2.fromOffset(42, -32)
		mover.GroupTransparency = 0
	end
	return s
end

function builders.Shells(gui, cfg)
	local root = centered(gui)
	local s = { root = root, segments = {} }
	local total = cfg.MagSize
	local width = total * 9
	local left = -width / 2

	for i = 1, total do
		local shell = frame(root, UDim2.fromOffset(6, 16), UDim2.fromOffset(left + (i - 1) * 9, 44), GOLD)
		round(shell, UDim.new(0, 3))
		s.segments[i] = shell
	end
	s.number, s.name, s.scale = readout(root, UDim2.fromOffset(left, 8), UDim2.fromOffset(left + 36, 18))

	-- Cinta de peligro que avanza al recargar
	local tape = frame(root, UDim2.fromOffset(0, 6), UDim2.fromOffset(left, 66), GOLD)
	tape.Visible = false
	local stripes = {}
	local count = 9
	for i = 0, count - 1 do
		local color = i % 2 == 0 and GOLD or DARK
		table.insert(stripes, ColorSequenceKeypoint.new(i / count, color))
		table.insert(stripes, ColorSequenceKeypoint.new(i == count - 1 and 1 or (i + 1) / count - 0.0001, color))
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(stripes)
	gradient.Rotation = 20
	gradient.Parent = tape

	function s.onReloadStart(duration)
		tape.Size = UDim2.fromOffset(0, 6)
		tape.Visible = true
		TweenService:Create(tape, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.fromOffset(width, 6) }):Play()
	end
	function s.onReloadEnd()
		tape.Visible = false
	end
	return s
end

function builders.Drum(gui)
	local root = centered(gui)
	local s = { root = root, segments = {}, spin = 0 }

	local drum = frame(root, UDim2.fromOffset(46, 46), UDim2.fromOffset(34, -23), DARK)
	round(drum)
	local stroke = Instance.new("UIStroke")
	stroke.Color = BEIGE
	stroke.Thickness = 3
	stroke.Parent = drum

	for i = 1, 6 do
		local angle = (i - 1) / 6 * math.pi * 2 - math.pi / 2
		local chamber = frame(drum, UDim2.fromOffset(11, 11), UDim2.new(0.5, math.cos(angle) * 14, 0.5, math.sin(angle) * 14), GOLD, Vector2.new(0.5, 0.5))
		round(chamber)
		s.segments[i] = chamber
	end

	s.number, s.name, s.scale = readout(root, UDim2.fromOffset(90, -22), UDim2.fromOffset(90, 8))

	-- Gira una recámara por disparo
	function s.onShot()
		s.spin += 60
		TweenService:Create(drum, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Rotation = s.spin }):Play()
	end
	-- Da una vuelta completa al recargar
	function s.onReloadStart(duration)
		s.spin += 360
		TweenService:Create(drum, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Rotation = s.spin }):Play()
	end
	return s
end

local function setSegment(seg, on)
	TweenService:Create(seg, TweenInfo.new(0.12), { BackgroundTransparency = on and 0 or OFF }):Play()
end

local function startReload(s, duration)
	s.reloading = true
	s.token += 1
	local token = s.token
	local function alive()
		return s.token == token
	end

	-- El cargador gastado se vacía y se rellena una bala tras otra
	for _, seg in s.segments do
		seg.BackgroundTransparency = OFF
	end
	local total = #s.segments
	for i, seg in s.segments do
		task.delay(duration * i / (total + 1), function()
			if alive() then
				setSegment(seg, true)
			end
		end)
	end
	if s.onReloadStart then
		s.onReloadStart(duration, alive)
	end
end

local function endReload(s)
	s.reloading = false
	s.token += 1
	if s.onReloadEnd then
		s.onReloadEnd()
	end
end

function AmmoHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AmmoHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Un estilo por arma, ocultos hasta que se equipan
	local styles = {}
	for _, cfg in Config.Weapons do
		local s = builders[cfg.AmmoStyle or "Ring"](gui, cfg)
		s.cfg = cfg
		s.reloading = false
		s.token = 0
		s.lastAmmo = cfg.MagSize
		s.root.Visible = false
		styles[cfg.Name] = s
	end

	local current = nil

	-- reserve = -1 es munición infinita
	Remotes.AmmoUpdate.OnClientEvent:Connect(function(ammo, reserve, magSize, reloading, weaponName)
		local s = styles[weaponName]
		if not s then
			return
		end
		if current and current ~= s then
			endReload(current)
			current.root.Visible = false
		end
		current = s
		s.root.Visible = true

		s.number.Text = tostring(ammo)
		s.number.TextColor3 = ammo <= magSize * 0.25 and LOW or Color3.new(1, 1, 1)
		s.name.Text = `{weaponName} · {reserve < 0 and "∞" or reserve}`

		if reloading then
			if not s.reloading then
				startReload(s, s.cfg.ReloadTime)
			end
		else
			if s.reloading then
				endReload(s)
			elseif ammo < s.lastAmmo then
				-- Disparo: un destello en el número y, si el estilo lo usa, gira el tambor
				s.scale.Scale = 1.3
				TweenService:Create(s.scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
				if s.onShot then
					s.onShot()
				end
			end
			local total = #s.segments
			local lit = math.ceil(ammo / magSize * total - 1e-6)
			for i, seg in s.segments do
				setSegment(seg, i <= lit)
			end
		end
		s.lastAmmo = ammo
	end)

	Remotes.Sync:FireServer()
end

return AmmoHud
