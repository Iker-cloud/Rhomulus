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
local Difficulties = require(ReplicatedStorage.Shared.Difficulties)
local Progress = require(ReplicatedStorage.Shared.Progress)
local Lang = require(ReplicatedStorage.Shared.Lang)

local player = Players.LocalPlayer

local PALETTES = {
	Victory = {
		title = "VICTORY",
		accent = Color3.fromRGB(245, 196, 60),
		glow = Color3.fromRGB(255, 214, 90),
		rowTint = Color3.fromRGB(38, 32, 14),
		killsColor = Color3.fromRGB(245, 196, 60),
		damageColor = Color3.new(1, 1, 1),
	},
	Defeat = {
		title = "DEFEAT",
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

	local current = nil -- { holder, connection, applyXp }
	local pendingXp = nil -- lista de XpGain que llegó antes de que la tarjeta estuviera lista

	local function clear()
		pendingXp = nil
		if current then
			current.connection:Disconnect()
			current.holder:Destroy()
			current = nil
		end
	end

	local recordSink = nil -- recibe el récord de extracción cuando el servidor lo manda (Remotes.Record)

	local function show(won, stats, awards, extra)
		recordSink = nil
		clear()
		local palette = won and PALETTES.Victory or PALETTES.Defeat
		local survivalWaves = extra and extra.waves -- modo Survival: no hay victoria, el título es la oleada a la que llegaron
		if survivalWaves then
			palette = table.clone(PALETTES.Defeat)
			palette.title = survivalWaves > 0 and `WAVE {survivalWaves}` or "OVERRUN"
		end

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
		tableRow(board, 34, { "PLAYER", "KILLS", "REVIVIDOS", "DAMAGE TAKEN" }, { gray, gray, gray, gray }, 12, Enum.Font.GothamBold)

		table.sort(stats, function(a, b)
			return a.kills > b.kills
		end)
		local rows = {}
		local byUser = {} -- [userId] = { applyXp } para poner el XP cuando llegue
		for _, entry in stats do
			local white = Color3.new(1, 1, 1)
			local row = tableRow(
				board,
				64,
				{ entry.name, tostring(entry.kills), tostring(entry.revives), tostring(entry.damage) },
				{ white, palette.killsColor, white, palette.damageColor },
				18,
				Enum.Font.GothamBold,
				palette.rowTint
			)
			row.BackgroundTransparency = 1
			-- Los textos van arriba; debajo del nombre quedan el nivel y la barra de XP
			for _, cell in row:GetChildren() do
				if cell:IsA("TextLabel") then
					cell.Size = UDim2.new(cell.Size.X.Scale, cell.Size.X.Offset, 0, 30)
					cell.Position = UDim2.new(cell.Position.X.Scale, cell.Position.X.Offset, 0, 4)
				end
			end
			local nameCell = row:FindFirstChildWhichIsA("TextLabel")
			nameCell.Position = UDim2.new(0, 60, 0, 4)
			nameCell.Size = UDim2.new(0.4, -60, 0, 30)

			-- Avatar del jugador (su cara de Roblox)
			local avatar = Instance.new("ImageLabel")
			avatar.Position = UDim2.fromOffset(10, 10)
			avatar.Size = UDim2.fromOffset(42, 42)
			avatar.BackgroundColor3 = Color3.fromRGB(30, 26, 24)
			avatar.BorderSizePixel = 0
			avatar.ScaleType = Enum.ScaleType.Crop
			avatar.Parent = row
			Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
			local ring = Instance.new("UIStroke")
			ring.Color = palette.accent
			ring.Thickness = 2
			ring.Parent = avatar
			if entry.userId then
				task.spawn(function()
					local ok, content = pcall(function()
						return Players:GetUserThumbnailAsync(entry.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
					end)
					if ok and content and avatar.Parent then
						avatar.Image = content
					end
				end)
			end

			-- Nivel y XP ganado, y la barra del nivel (se llenan cuando llega Remotes.XpGain)
			local levelText = label(row, "", 14, Color3.fromRGB(190, 184, 176))
			levelText.Position = UDim2.fromOffset(60, 33)
			levelText.Size = UDim2.new(0.5, -60, 0, 16)
			levelText.TextXAlignment = Enum.TextXAlignment.Left
			local xpText = label(row, "", 14, palette.accent, Enum.Font.GothamBlack)
			xpText.AnchorPoint = Vector2.new(1, 0)
			xpText.Position = UDim2.new(1, -14, 0, 33)
			xpText.Size = UDim2.new(0.5, 0, 0, 16)
			xpText.TextXAlignment = Enum.TextXAlignment.Right
			local barBack = Instance.new("Frame")
			barBack.Position = UDim2.fromOffset(60, 54)
			barBack.Size = UDim2.new(1, -74, 0, 6)
			barBack.BackgroundColor3 = Color3.fromRGB(40, 36, 34)
			barBack.BorderSizePixel = 0
			barBack.Visible = false
			barBack.Parent = row
			Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)
			local barFill = Instance.new("Frame")
			barFill.Size = UDim2.fromScale(0, 1)
			barFill.BackgroundColor3 = palette.accent
			barFill.BorderSizePixel = 0
			barFill.Parent = barBack
			Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

			local function applyXp(info)
				local levelBefore, intoBefore, needBefore = Progress.fromTotal(info.before)
				local levelAfter, intoAfter, needAfter = Progress.fromTotal(info.after)
				barBack.Visible = true
				local line = (info.rhoms or 0) > 0 and `+{info.gained} XP  ·  +{info.rhoms} RHOMS` or `+{info.gained} XP`
				if (info.missionRhoms or 0) > 0 then
					line ..= `  ·  {Lang.tr("MISSION")} +{info.missionRhoms}`
				end
				xpText.Text = info.crate and `{line}  ·  +1 {string.upper(info.crate)} CRATE` or line
				levelText.Text = `LEVEL {levelBefore}`
				barFill.Size = UDim2.fromScale(needBefore > 0 and intoBefore / needBefore or 1, 1)
				task.spawn(function()
					task.wait(0.9) -- primero se leen las estadísticas
					local tween = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					if levelAfter > levelBefore then
						TweenService:Create(barFill, tween, { Size = UDim2.fromScale(1, 1) }):Play()
						task.wait(0.8)
						if not barFill.Parent then
							return
						end
						levelText.Text = `LEVEL {levelAfter}!`
						levelText.TextColor3 = palette.accent
						barFill.Size = UDim2.fromScale(0, 1)
					end
					TweenService:Create(barFill, tween, { Size = UDim2.fromScale(needAfter > 0 and intoAfter / needAfter or 1, 1) }):Play()
				end)
			end
			if entry.userId then
				byUser[entry.userId] = applyXp
			end
			table.insert(rows, row)
		end

		local function applyXpList(list)
			for _, info in list do
				local apply = byUser[info.userId]
				if apply then
					apply(info)
				end
			end
		end

		-- Récord de extracción y reconocimientos ("el que más mató", "el que más murió"…): van juntos entre la tabla y los botones
		local extras = Instance.new("Frame")
		extras.BackgroundTransparency = 1
		extras.Size = UDim2.new(1, 0, 0, 0)
		extras.AutomaticSize = Enum.AutomaticSize.Y
		extras.LayoutOrder = 5
		extras.Parent = content
		local extrasLayout = Instance.new("UIListLayout")
		extrasLayout.Padding = UDim.new(0, 8)
		extrasLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		extrasLayout.SortOrder = Enum.SortOrder.LayoutOrder
		extrasLayout.Parent = extras

		local function clock(seconds)
			seconds = math.max(0, math.floor(seconds + 0.5))
			return string.format("%d:%02d", seconds // 60, seconds % 60)
		end
		if won or survivalWaves then
			recordSink = function(info)
				if not extras.Parent or extras:FindFirstChild("RecordLine") then
					return
				end
				local difficulty = Difficulties.get(info.difficulty)
				local line = Instance.new("TextLabel")
				line.Name = "RecordLine"
				line.LayoutOrder = 1
				line.BackgroundTransparency = 1
				line.Size = UDim2.new(1, 0, 0, 26)
				line.Font = Enum.Font.GothamBold
				line.TextSize = 15
				line.RichText = true
				line.TextColor3 = Color3.fromRGB(190, 184, 176)
				local accent = string.format("#%02X%02X%02X", palette.accent.R * 255, palette.accent.G * 255, palette.accent.B * 255)
				if info.waves then
					-- (el texto enriquecido no se traduce solo: se traducen las piezas antes de armarlo)
					local wave = Lang.tr("WAVE")
					if info.isRecord then
						line.Text = `{wave} {info.waves}  ·  <font color="{accent}">{Lang.tr("NEW RECORD!")}</font>`
					elseif info.best then
						line.Text = `{wave} {info.waves}  ·  {Lang.tr("RECORD")}: <font color="{accent}">{wave} {info.best}</font>`
					else
						line.Text = `{wave} {info.waves}`
					end
				elseif info.isRecord then
					line.Text = `TIME {clock(info.time)}  ·  <font color="{accent}">NEW {difficulty.Upper} RECORD!</font>`
				elseif info.best then
					line.Text = `TIME {clock(info.time)}  ·  {difficulty.Upper} RECORD: <font color="{accent}">{clock(info.best)}</font>`
				else
					line.Text = `TIME {clock(info.time)}`
				end
				line.Parent = extras
			end
		end

		if awards and #awards > 0 then
			local heading = Instance.new("TextLabel")
			heading.LayoutOrder = 2
			heading.BackgroundTransparency = 1
			heading.Size = UDim2.new(1, 0, 0, 22)
			heading.Font = Enum.Font.GothamBold
			heading.TextSize = 12
			heading.TextColor3 = Color3.fromRGB(150, 146, 140)
			heading.Text = "R E C O N O C I M I E N T O S"
			heading.Parent = extras
			local grid = Instance.new("Frame")
			grid.LayoutOrder = 3
			grid.BackgroundTransparency = 1
			grid.Size = UDim2.new(1, 0, 0, 0)
			grid.AutomaticSize = Enum.AutomaticSize.Y
			grid.Parent = extras
			local cells = Instance.new("UIGridLayout")
			cells.CellSize = UDim2.fromOffset(176, 76)
			cells.CellPadding = UDim2.fromOffset(8, 8)
			cells.HorizontalAlignment = Enum.HorizontalAlignment.Center
			cells.SortOrder = Enum.SortOrder.LayoutOrder
			cells.Parent = grid
			for index, award in awards do
				local chip = Instance.new("Frame")
				chip.LayoutOrder = index
				chip.BackgroundColor3 = Color3.fromRGB(22, 20, 18)
				chip.BorderSizePixel = 0
				chip.Parent = grid
				Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 6)
				local chipStroke = Instance.new("UIStroke")
				chipStroke.Color = palette.accent
				chipStroke.Transparency = 0.45
				chipStroke.Thickness = 1.5
				chipStroke.Parent = chip
				local function chipText(text, y, height, size, color, font)
					local l = Instance.new("TextLabel")
					l.BackgroundTransparency = 1
					l.Position = UDim2.fromOffset(8, y)
					l.Size = UDim2.new(1, -16, 0, height)
					l.Font = font
					l.TextSize = size
					l.TextColor3 = color
					l.TextXAlignment = Enum.TextXAlignment.Center
					l.Text = text
					l.Parent = chip
					return l
				end
				chipText(award.title, 6, 16, 12, palette.accent, Enum.Font.GothamBlack)
				local names = {}
				for _, winner in award.winners do
					table.insert(names, winner.name)
				end
				local nameLabel = chipText(table.concat(names, " y "), 24, 26, 20, Color3.new(1, 1, 1), Enum.Font.GothamBlack)
				nameLabel.TextScaled = true
				local limit = Instance.new("UITextSizeConstraint")
				limit.MaxTextSize = 20
				limit.Parent = nameLabel
				chipText(`{award.value} {award.unit}`, 54, 16, 13, Color3.fromRGB(176, 170, 162), Enum.Font.GothamBold)
			end
		end

		-- Dos botones en una fila: OTRA PARTIDA (con la cuenta atrás hasta la siguiente; si todos lo piden se adelanta) y VOLVER AL MENÚ
		-- (teletransporta al lugar del Menú)
		local buttons = Instance.new("Frame")
		buttons.LayoutOrder = 6
		buttons.BackgroundTransparency = 1
		buttons.Size = UDim2.new(1, 0, 0, 46)
		buttons.Parent = content
		local row = Instance.new("UIListLayout")
		row.FillDirection = Enum.FillDirection.Horizontal
		row.Padding = UDim.new(0, 10)
		row.SortOrder = Enum.SortOrder.LayoutOrder
		row.Parent = buttons

		local again = Instance.new("TextButton")
		again.LayoutOrder = 1
		again.Size = UDim2.new(0.58, -5, 1, 0)
		again.BackgroundColor3 = palette.accent
		again.AutoButtonColor = true
		again.BorderSizePixel = 0
		again.Font = Enum.Font.GothamBlack
		again.TextSize = 17
		again.TextColor3 = Color3.fromRGB(14, 13, 13)
		again.Text = "PLAY AGAIN"
		again.Parent = buttons
		Instance.new("UICorner", again).CornerRadius = UDim.new(0, 6)
		again.Activated:Connect(function()
			if not player:GetAttribute("PlayAgain") then
				player:SetAttribute("PlayAgain", true) -- se ve al instante; el servidor lo confirma
				Remotes.PlayAgain:FireServer()
			end
		end)

		local back = Instance.new("TextButton")
		back.LayoutOrder = 2
		back.Size = UDim2.new(0.42, -5, 1, 0)
		back.BackgroundColor3 = Color3.fromRGB(14, 13, 13)
		back.AutoButtonColor = true
		back.BorderSizePixel = 0
		back.Font = Enum.Font.GothamBold
		back.TextSize = 14
		back.TextColor3 = palette.accent
		back.Text = "BACK TO MENU"
		back.Parent = buttons
		Instance.new("UICorner", back).CornerRadius = UDim.new(0, 6)
		local backStroke = Instance.new("UIStroke")
		backStroke.Color = palette.accent
		backStroke.Thickness = 1.5
		backStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		backStroke.Parent = back
		local leaving = false
		back.Activated:Connect(function()
			if leaving then
				return
			end
			leaving = true
			back.Text = "RETURNING…"
			local ok, err = pcall(function()
				TeleportService:Teleport(Places.Menu, player)
			end)
			if not ok then
				warn("[ResultHud] No se pudo volver al menú (en Studio no funciona):", err)
				back.Text = "BACK TO MENU"
				leaving = false
			end
		end)

		-- El texto de OTRA PARTIDA lleva los segundos que faltan y, tras pulsarlo, cuántos del equipo ya lo pidieron
		local function refreshAgain()
			local ends = workspace:GetAttribute("ResultEnd")
			local seconds = ends and math.max(0, math.ceil(ends - workspace:GetServerTimeNow())) or nil
			if player:GetAttribute("PlayAgain") then
				local ready, total = 0, 0
				for _, other in Players:GetPlayers() do
					total += 1
					if other:GetAttribute("PlayAgain") then
						ready += 1
					end
				end
				again.Text = `READY {ready}/{total}` .. (seconds and ` · {seconds}` or "")
				again.BackgroundColor3 = Color3.fromRGB(70, 66, 60)
				again.TextColor3 = Color3.new(1, 1, 1)
			else
				again.Text = "PLAY AGAIN" .. (seconds and ` · {seconds}` or "")
			end
		end
		refreshAgain()

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
			refreshAgain()
			title.TextStrokeTransparency = 0.7 - 0.25 * pulse
		end)

		current = { holder = holder, connection = connection, applyXp = applyXpList }
		if pendingXp then
			applyXpList(pendingXp)
			pendingXp = nil
		end
	end

	Remotes.Results.OnClientEvent:Connect(show)
	Remotes.Record.OnClientEvent:Connect(function(info)
		if recordSink then
			recordSink(info)
		end
	end)
	Remotes.XpGain.OnClientEvent:Connect(function(list)
		if current then
			current.applyXp(list)
		else
			pendingXp = list
		end
	end)

	-- Al salir de la etapa de resultados (vuelve al lobby), se quita la pantalla
	workspace:GetAttributeChangedSignal("Stage"):Connect(function()
		if workspace:GetAttribute("Stage") ~= "Result" then
			clear()
		end
	end)
end

return ResultHud
