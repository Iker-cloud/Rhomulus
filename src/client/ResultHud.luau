-- Pantallas de resultado: VICTORIA (dorada, hexágono con estrella) y DERROTA (roja, cinta de peligro, calavera y sangre).
-- Las dos llevan la misma tabla de estadísticas: jugador, kills, revividos y daño recibido.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")

local Icons = require(script.Parent.Icons)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Places = require(ReplicatedStorage.Shared.Places)

local player = Players.LocalPlayer

local PALETTES = {
	Victory = {
		title = "VICTORIA",
		accent = Color3.fromRGB(245, 196, 60),
		glow = Color3.fromRGB(255, 214, 90),
		rowTint = Color3.fromRGB(38, 32, 14),
		killsColor = Color3.fromRGB(245, 196, 60),
		damageColor = Color3.new(1, 1, 1),
	},
	Defeat = {
		title = "DERROTA",
		accent = Color3.fromRGB(226, 66, 54),
		glow = Color3.fromRGB(255, 80, 60),
		rowTint = Color3.fromRGB(34, 15, 15),
		killsColor = Color3.new(1, 1, 1),
		damageColor = Color3.fromRGB(226, 66, 54),
	},
}

local COLUMNS = {
	-- x0, x1 (en escala), alineación
	{ 0.00, 0.40, Enum.TextXAlignment.Left },
	{ 0.40, 0.56, Enum.TextXAlignment.Center },
	{ 0.56, 0.78, Enum.TextXAlignment.Center },
	{ 0.78, 1.00, Enum.TextXAlignment.Right },
}

local ResultHud = {}

local function label(parent, text, size, color, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color
	l.Text = text
	l.Parent = parent
	return l
end

-- Una fila de la tabla con cuatro columnas
local function tableRow(parent, height, cells, colors, sizes, fonts, background)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, height)
	row.BackgroundColor3 = background or Color3.new()
	row.BackgroundTransparency = background and 0 or 1
	row.BorderSizePixel = 0
	row.Parent = parent
	for i, col in COLUMNS do
		local cell = label(row, cells[i], sizes, colors[i], fonts)
		cell.Position = UDim2.new(col[1], i == 1 and 14 or 0, 0, 0)
		cell.Size = UDim2.new(col[2] - col[1], i == 1 and -14 or (i == 4 and -14 or 0), 1, 0)
		cell.TextXAlignment = col[3]
		if sizes == 12 then
			cell.TextWrapped = true
		end
	end
	return row
end

function ResultHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ResultHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local current = nil -- { holder, connection }

	local function clear()
		if current then
			current.connection:Disconnect()
			current.holder:Destroy()
			current = nil
		end
	end

	local function show(won, stats)
		clear()
		local palette = won and PALETTES.Victory or PALETTES.Defeat

		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1)
		holder.Parent = gui

		-- Brillo detrás de la tarjeta
		local glow = Instance.new("Frame")
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.Size = UDim2.fromOffset(700, 520)
		glow.BackgroundColor3 = palette.glow
		glow.BackgroundTransparency = 0.9
		glow.BorderSizePixel = 0
		glow.Parent = holder
		Instance.new("UICorner", glow).CornerRadius = UDim.new(0, 40)

		local card = Instance.new("CanvasGroup")
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.5)
		card.Size = UDim2.fromOffset(620, 0)
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.BackgroundColor3 = Color3.fromRGB(14, 13, 13)
		card.BorderSizePixel = 0
		card.GroupTransparency = 1
		card.Parent = holder
		local stroke = Instance.new("UIStroke")
		stroke.Color = palette.accent
		stroke.Transparency = 0.35
		stroke.Thickness = 1.5
		stroke.Parent = card
		local scale = Instance.new("UIScale")
		scale.Scale = 0.88
		scale.Parent = card

		-- Borde superior: línea dorada o cinta de peligro roja
		if won then
			local line = Instance.new("Frame")
			line.Size = UDim2.new(1, 0, 0, 4)
			line.BorderSizePixel = 0
			line.BackgroundColor3 = palette.accent
			line.Parent = card
			local fade = Instance.new("UIGradient")
			fade.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 110, 20)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 226, 120)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 110, 20)),
			})
			fade.Parent = line
		else
			Icons.tape(card, UDim2.new(1, 0, 0, 12), UDim2.fromOffset(0, 0), palette.accent, Color3.fromRGB(20, 12, 12))
		end

		local content = Instance.new("Frame")
		content.BackgroundTransparency = 1
		content.Size = UDim2.new(1, 0, 0, 0)
		content.AutomaticSize = Enum.AutomaticSize.Y
		content.Parent = card
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = content
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 30)
		padding.PaddingBottom = UDim.new(0, 28)
		padding.PaddingLeft = UDim.new(0, 28)
		padding.PaddingRight = UDim.new(0, 28)
		padding.Parent = content

		-- Emblema
		local emblem = Instance.new("Frame")
		emblem.BackgroundTransparency = 1
		emblem.Size = UDim2.fromOffset(84, 84)
		emblem.LayoutOrder = 1
		emblem.Parent = content
		if won then
			Icons.hexStar(emblem, 36, palette.accent)
		else
			local circle = Instance.new("Frame")
			circle.AnchorPoint = Vector2.new(0.5, 0.5)
			circle.Position = UDim2.fromScale(0.5, 0.5)
			circle.Size = UDim2.fromOffset(76, 76)
			circle.BackgroundColor3 = Color3.fromRGB(16, 12, 12)
			circle.BorderSizePixel = 0
			circle.Parent = emblem
			Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
			local ring = Instance.new("UIStroke")
			ring.Color = palette.accent
			ring.Thickness = 3
			ring.Parent = circle
			Icons.skull(circle, 2.1)
		end

		-- Título
		local titleHolder = Instance.new("Frame")
		titleHolder.BackgroundTransparency = 1
		titleHolder.Size = UDim2.new(1, 0, 0, 72)
		titleHolder.LayoutOrder = 2
		titleHolder.Parent = content

		local shadow = label(titleHolder, palette.title, 64, Color3.fromRGB(90, 20, 18), Enum.Font.GothamBlack)
		shadow.Size = UDim2.fromScale(1, 1)
		shadow.Position = UDim2.fromOffset(4, 4)
		shadow.Visible = not won
		local title = label(titleHolder, palette.title, 64, palette.accent, Enum.Font.GothamBlack)
		title.Size = UDim2.fromScale(1, 1)
		title.TextStrokeColor3 = palette.glow
		title.TextStrokeTransparency = 0.6

		if won then
			-- Líneas doradas a los lados del título
			for _, side in { -1, 1 } do
				local line = Instance.new("Frame")
				line.AnchorPoint = Vector2.new(0.5, 0.5)
				line.Position = UDim2.new(0.5, side * 235, 0.5, 0)
				line.Size = UDim2.fromOffset(70, 2)
				line.BackgroundColor3 = palette.accent
				line.BorderSizePixel = 0
				line.Parent = titleHolder
			end
		end

		-- Línea de sangre que gotea bajo el título (derrota)
		local drips = {}
		if not won then
			local blood = Instance.new("Frame")
			blood.Size = UDim2.new(1, 0, 0, 30)
			blood.BackgroundTransparency = 1
			blood.LayoutOrder = 3
			blood.Parent = content
			local bar = Instance.new("Frame")
			bar.AnchorPoint = Vector2.new(0.5, 0)
			bar.Position = UDim2.new(0.5, 0, 0, 0)
			bar.Size = UDim2.fromOffset(300, 5)
			bar.BackgroundColor3 = Color3.fromRGB(160, 24, 20)
			bar.BorderSizePixel = 0
			bar.Parent = blood
			Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
			for _, drip in { { -90, 14 }, { -20, 8 }, { 30, 22 }, { 100, 11 } } do
				local d = Instance.new("Frame")
				d.AnchorPoint = Vector2.new(0.5, 0)
				d.Position = UDim2.new(0.5, drip[1], 0, 3)
				d.Size = UDim2.fromOffset(5, 0)
				d.BackgroundColor3 = Color3.fromRGB(160, 24, 20)
				d.BorderSizePixel = 0
				d.Parent = blood
				Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
				table.insert(drips, { frame = d, height = drip[2] })
			end
		end

		-- Tabla de estadísticas
		local board = Instance.new("Frame")
		board.BackgroundTransparency = 1
		board.Size = UDim2.new(1, 0, 0, 0)
		board.AutomaticSize = Enum.AutomaticSize.Y
		board.LayoutOrder = 4
		board.Parent = content
		local boardLayout = Instance.new("UIListLayout")
		boardLayout.Padding = UDim.new(0, 4)
		boardLayout.Parent = board

		local gray = Color3.fromRGB(150, 146, 140)
		tableRow(board, 34, { "JUGADOR", "KILLS", "REVIVIDOS", "DAÑO RECIBIDO" }, { gray, gray, gray, gray }, 12, Enum.Font.GothamBold)

		table.sort(stats, function(a, b)
			return a.kills > b.kills
		end)
		local rows = {}
		for _, entry in stats do
			local white = Color3.new(1, 1, 1)
			local row = tableRow(
				board,
				40,
				{ entry.name, tostring(entry.kills), tostring(entry.revives), tostring(entry.damage) },
				{ white, palette.killsColor, white, palette.damageColor },
				20,
				Enum.Font.GothamBold,
				palette.rowTint
			)
			row.BackgroundTransparency = 1
			table.insert(rows, row)
		end

		-- Botón para volver al menú (teletransporta al lugar del Menú)
		local back = Instance.new("TextButton")
		back.LayoutOrder = 5
		back.Size = UDim2.new(1, 0, 0, 46)
		back.BackgroundColor3 = palette.accent
		back.AutoButtonColor = true
		back.BorderSizePixel = 0
		back.Font = Enum.Font.GothamBlack
		back.TextSize = 18
		back.TextColor3 = Color3.fromRGB(14, 13, 13)
		back.Text = "VOLVER AL MENÚ"
		back.Parent = content
		Instance.new("UICorner", back).CornerRadius = UDim.new(0, 6)
		local leaving = false
		back.Activated:Connect(function()
			if leaving then
				return
			end
			leaving = true
			back.Text = "VOLVIENDO…"
			local ok, err = pcall(function()
				TeleportService:Teleport(Places.Menu, player)
			end)
			if not ok then
				warn("[ResultHud] No se pudo volver al menú (en Studio no funciona):", err)
				back.Text = "VOLVER AL MENÚ"
				leaving = false
			end
		end)

		-- Animación de entrada: aparece creciendo, las filas se encienden una a una y las gotas bajan
		TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
		-- La tarjeta llega a tamaño completo, o al que quepa en pantallas bajas (celular)
		task.spawn(function()
			task.wait()
			local view = gui.AbsoluteSize
			local height = math.max(card.AbsoluteSize.Y / scale.Scale, 1)
			local target = math.clamp(math.min(view.X * 0.96 / 620, view.Y * 0.94 / height), 0.4, 1)
			TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
		end)
		for i, row in rows do
			task.delay(0.4 + 0.12 * i, function()
				if row.Parent then
					TweenService:Create(row, TweenInfo.new(0.25), { BackgroundTransparency = 0 }):Play()
				end
			end)
		end
		for i, drip in drips do
			task.delay(0.5 + 0.15 * i, function()
				if drip.frame.Parent then
					TweenService:Create(drip.frame, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Size = UDim2.fromOffset(5, drip.height),
					}):Play()
				end
			end)
		end

		-- El brillo y el borde laten suavemente
		local connection = RunService.Heartbeat:Connect(function()
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * 2.2)
			glow.BackgroundTransparency = 0.9 - 0.06 * pulse
			title.TextStrokeTransparency = 0.7 - 0.25 * pulse
		end)

		current = { holder = holder, connection = connection }
	end

	Remotes.Results.OnClientEvent:Connect(show)

	-- Al salir de la etapa de resultados (vuelve al lobby), se quita la pantalla
	workspace:GetAttributeChangedSignal("Stage"):Connect(function()
		if workspace:GetAttribute("Stage") ~= "Result" then
			clear()
		end
	end)
end

return ResultHud
