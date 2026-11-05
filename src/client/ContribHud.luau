-- PANEL TEMPORAL: cuántas latas ha sumado cada superviviente al total del equipo (matar, revivir, cargar), para no perderse.
-- Va debajo del cartel de LATAS. Solo lee el atributo "LatasEarned" de cada jugador (lo pone server/Points), así que el
-- diseño final se puede reemplazar sin tocar el servidor.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UiFit = require(script.Parent.UiFit)
local Paper = require(script.Parent.PaperStyle)
local localPlayer = Players.LocalPlayer

local PANEL_SHOW_TIME = 6 -- el panel se esconde solo; sale al ganar latas y mientras se mantiene Tab
local GAIN_SHOW_TIME = 1.5 -- segundos que se ve el "+25" junto al nombre
local ROW_HEIGHT = 24
local UserInputService = game:GetService("UserInputService")

local ContribHud = {}

function ContribHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ContribHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -24, 0, 160) -- justo debajo del cartel de LATAS
	panel.Size = UDim2.fromOffset(210, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Rotation = 0.6
	panel.Parent = gui
	Paper.paper(panel, 3)
	UiFit.scale(panel, 0.85)
	panel.Position = UDim2.new(1, -24, 0, 150)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = panel

	local title = Instance.new("TextLabel")
	title.LayoutOrder = -1000000
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 16)
	title.FontFace = Paper.Head
	title.TextSize = 15
	title.TextColor3 = Paper.Red
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "TEAM CONTRIBUTION"
	title.Parent = panel

	local visibleUntil = 0
	local rows = {} -- [Player] = { frame, name, number, gain, shown, gainUntil }

	local function buildRow(player)
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		frame.Parent = panel

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Size = UDim2.new(0.55, 0, 1, 0)
		name.FontFace = player == localPlayer and Paper.Head or Paper.Typewriter
		name.TextSize = 15
		name.TextColor3 = player == localPlayer and Paper.Red or Paper.Ink
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = player.DisplayName
		name.Parent = frame

		local gain = Instance.new("TextLabel")
		gain.BackgroundTransparency = 1
		gain.AnchorPoint = Vector2.new(1, 0)
		gain.Position = UDim2.new(0.8, 0, 0, 0)
		gain.Size = UDim2.new(0.25, 0, 1, 0)
		gain.FontFace = Paper.Head
		gain.TextSize = 14
		gain.TextColor3 = Paper.Green
		gain.TextXAlignment = Enum.TextXAlignment.Right
		gain.Text = ""
		gain.Parent = frame

		local number = Instance.new("TextLabel")
		number.BackgroundTransparency = 1
		number.AnchorPoint = Vector2.new(1, 0)
		number.Position = UDim2.new(1, 0, 0, 0)
		number.Size = UDim2.new(0.25, 0, 1, 0)
		number.FontFace = Paper.Head
		number.TextSize = 19
		number.TextColor3 = Paper.Ink
		number.TextXAlignment = Enum.TextXAlignment.Right
		number.Text = "0"
		number.Parent = frame

		rows[player] = { frame = frame, name = name, number = number, gain = gain, shown = 0, gainUntil = 0 }
	end

	local function refresh()
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			if not rows[player] then
				buildRow(player)
			end
			local row = rows[player]
			local total = player:GetAttribute("LatasEarned") or 0
			if total > row.shown then
				row.gain.Text = `+{total - row.shown}`
				row.gainUntil = now + GAIN_SHOW_TIME
				visibleUntil = now + PANEL_SHOW_TIME
			end
			if total ~= row.shown then
				row.shown = total
				row.number.Text = tostring(total)
			end
			if row.gainUntil ~= 0 and now > row.gainUntil then
				row.gain.Text = ""
				row.gainUntil = 0
			end
			row.name.Text = player.DisplayName
			row.frame.LayoutOrder = -total -- el que más aporta, arriba
		end
		panel.Visible = now < visibleUntil or UserInputService:IsKeyDown(Enum.KeyCode.Tab)
		for player, row in rows do
			if not player.Parent then
				row.frame:Destroy()
				rows[player] = nil
			end
		end
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.2 then
			elapsed = 0
			refresh()
		end
	end)
	refresh()
end

return ContribHud
