-- Dificultad en pantalla: (1) durante la votación del mapa, un panel con las cuatro dificultades; se vota con las teclas 1 a 4
-- (o tocando la fila en celular) y se ven los votos de todos; (2) el resto de la partida, una etiqueta arriba con la
-- dificultad en curso. El servidor (VoteRoom) cuenta los votos y publica DiffVotes_<id> en Workspace y DifficultyVote en cada jugador.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Difficulties = require(ReplicatedStorage.Shared.Difficulties)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Controls = require(script.Parent.Controls)
local Sfx = require(script.Parent.Sfx)

local UiFit = require(script.Parent.UiFit)
local player = Players.LocalPlayer
local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local OSWALD_LIGHT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Regular)
local DARK = Color3.fromRGB(18, 18, 20)
local PALE = Color3.fromRGB(215, 210, 200)
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
local ACTION = "DifficultyVoteKeys"
local ROW_HEIGHT = 84
local COMPACT_ROW_HEIGHT = 40 -- pantallas bajas: sin la descripción de cada dificultad

local DifficultyVote = {}

local function label(parent, str, size, position, textSize, color, align, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.FontFace = font or OSWALD
	l.TextSize = textSize
	l.TextColor3 = color
	l.Text = str
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Parent = parent
	return l
end

function DifficultyVote.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DifficultyVote"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 35
	gui.Parent = player:WaitForChild("PlayerGui")

	local compact = UiFit.isShort()
	local rowHeight = compact and COMPACT_ROW_HEIGHT or ROW_HEIGHT

	-- Panel de votación (izquierda, centrado en vertical)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 20, 0.5, compact and -30 or 60) -- bajo el aviso de la radio (en pantallas bajas más arriba: abajo está la jeringa)
	panel.Size = UDim2.fromOffset(compact and 260 or 340, 64 + #Difficulties.Order * rowHeight)
	panel.BackgroundColor3 = DARK
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	UiFit.scale(panel)
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(246, 196, 70)
	panelStroke.Thickness = 2
	panelStroke.Parent = panel
	label(panel, "DIFICULTAD", UDim2.new(1, -24, 0, 30), UDim2.fromOffset(16, 8), 26, Color3.fromRGB(246, 196, 70))
	label(panel, Controls.isTouch() and "Toca una dificultad para votar" or "Pulsa 1 a 4 para votar", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(16, 38), 15, PALE, nil, OSWALD_LIGHT)

	local rows = {}
	for i, id in Difficulties.Order do
		local d = Difficulties[id]
		local row = Instance.new("TextButton")
		row.AutoButtonColor = false
		row.Text = ""
		row.Position = UDim2.fromOffset(10, 64 + (i - 1) * rowHeight)
		row.Size = UDim2.new(1, -20, 0, rowHeight - 6)
		row.BackgroundColor3 = Color3.fromRGB(34, 34, 38)
		row.BorderSizePixel = 0
		row.Parent = panel
		local stroke = Instance.new("UIStroke")
		stroke.Color = d.Color
		stroke.Thickness = 2
		stroke.Transparency = 1
		stroke.Parent = row
		label(row, `{i}`, UDim2.fromOffset(20, 24), UDim2.fromOffset(8, 4), 20, Color3.fromRGB(150, 146, 140))
		label(row, d.Upper, UDim2.new(1, -90, 0, 26), UDim2.fromOffset(30, 3), 22, d.Color)
		local count = label(row, "0", UDim2.fromOffset(40, 26), UDim2.new(1, -48, 0, 3), 22, Color3.new(1, 1, 1), Enum.TextXAlignment.Right)
		local desc = label(row, d.Description, UDim2.new(1, -20, 0, 54), UDim2.fromOffset(10, 30), 13, PALE, nil, OSWALD_LIGHT)
		desc.TextWrapped = true
		desc.Visible = not compact
		row.Activated:Connect(function()
			Sfx.play("Select", 0.1)
			Remotes.VoteDifficulty:FireServer(id)
		end)
		rows[id] = { stroke = stroke, count = count }
	end

	local function refreshVotes()
		local mine = player:GetAttribute("DifficultyVote")
		for id, row in rows do
			row.count.Text = tostring(workspace:GetAttribute("DiffVotes_" .. id) or 0)
			row.stroke.Transparency = (id == mine) and 0 or 1
		end
	end
	for _, id in Difficulties.Order do
		workspace:GetAttributeChangedSignal("DiffVotes_" .. id):Connect(refreshVotes)
	end
	player:GetAttributeChangedSignal("DifficultyVote"):Connect(refreshVotes)

	-- Etiqueta de la dificultad en curso (arriba al centro)
	local tag = Instance.new("TextLabel")
	tag.AnchorPoint = Vector2.new(0.5, 0)
	tag.Position = UDim2.new(0.5, 0, 0, 8)
	tag.Size = UDim2.fromOffset(280, 24)
	tag.BackgroundTransparency = 1
	tag.FontFace = OSWALD
	tag.TextSize = 18
	tag.TextStrokeTransparency = 0.5
	tag.Parent = gui

	local function update()
		local voting = workspace:GetAttribute("Stage") == "Vote"
		panel.Visible = voting
		local d = Difficulties.get(workspace:GetAttribute("Difficulty"))
		tag.Text = `DIFICULTAD · {d.Upper}`
		tag.TextColor3 = d.Color
		tag.Visible = not voting and workspace:GetAttribute("Stage") ~= nil
		if voting then
			refreshVotes()
			-- Con el panel abierto, las teclas 1 a 4 votan (y no cambian de arma)
			ContextActionService:BindActionAtPriority(ACTION, function(_, state, input)
				if state == Enum.UserInputState.Begin then
					local index = table.find(KEYS, input.KeyCode)
					if index then
						Sfx.play("Select", 0.1)
						Remotes.VoteDifficulty:FireServer(Difficulties.Order[index])
					end
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value, table.unpack(KEYS))
		else
			ContextActionService:UnbindAction(ACTION)
		end
	end
	workspace:GetAttributeChangedSignal("Stage"):Connect(update)
	workspace:GetAttributeChangedSignal("Difficulty"):Connect(update)
	update()
end

return DifficultyVote
