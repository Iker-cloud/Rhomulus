-- Marcador del modo Survival: oleada actual y cuántos zombies quedan (o la cuenta atrás de la pausa), y un aviso grande al empezar cada
-- oleada. Lee los atributos de Workspace que publica GameState.survival: Wave, WaveTotal, WaveLeft, WaveBoss y WaveBreakEnd.
-- Los textos van en inglés; Lang.watch los traduce solo (pares con {1} en shared/LangEs).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Paper = require(script.Parent.PaperStyle)
local Sfx = require(script.Parent.Sfx)
local UiFit = require(script.Parent.UiFit)

local player = Players.LocalPlayer

local WaveHud = {}

local function label(parent, font, size, color)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.FontFace = font
	text.TextSize = size
	text.TextColor3 = color
	text.Parent = parent
	return text
end

function WaveHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WaveHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Panel de expediente arriba al centro (donde va la etiqueta de dificultad en las demás partidas)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 8)
	panel.Size = UDim2.fromOffset(250, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Rotation = -0.6
	panel.Visible = false
	panel.Parent = gui
	Paper.paper(panel, 3)
	UiFit.scale(panel, 0.9)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 2)
	layout.Parent = panel

	local title = label(panel, Paper.Head, 34, Paper.Ink)
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, 0, 0, 38)
	local status = label(panel, Paper.Typewriter, 16, Paper.Soft)
	status.LayoutOrder = 2
	status.Size = UDim2.new(1, 0, 0, 20)
	local track = Instance.new("Frame")
	track.LayoutOrder = 3
	track.Size = UDim2.new(1, 0, 0, 6)
	track.BackgroundColor3 = Paper.PaperDark
	track.BorderSizePixel = 0
	track.Parent = panel
	local trackStroke = Instance.new("UIStroke")
	trackStroke.Color = Paper.Ink
	trackStroke.Thickness = 1.5
	trackStroke.Parent = track
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Paper.Red
	fill.BorderSizePixel = 0
	fill.Parent = track

	-- Aviso grande al empezar una oleada
	local banner = Instance.new("CanvasGroup")
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.3)
	banner.Size = UDim2.fromOffset(640, 150)
	banner.BackgroundTransparency = 1
	banner.GroupTransparency = 1
	banner.Parent = gui
	local bannerScale = Instance.new("UIScale")
	bannerScale.Parent = banner
	UiFit.scale(banner, 0.9)
	local bannerTitle = label(banner, Paper.Head, 96, Color3.fromRGB(240, 232, 214))
	bannerTitle.Size = UDim2.new(1, 0, 0, 100)
	bannerTitle.TextStrokeColor3 = Color3.fromRGB(20, 12, 10)
	bannerTitle.TextStrokeTransparency = 0.15
	local bannerSub = label(banner, Paper.Typewriter, 26, Paper.Red)
	bannerSub.Position = UDim2.fromOffset(0, 104)
	bannerSub.Size = UDim2.new(1, 0, 0, 34)
	bannerSub.TextStrokeColor3 = Color3.fromRGB(20, 12, 10)
	bannerSub.TextStrokeTransparency = 0.2

	local bannerToken = 0
	local function showBanner(wave, boss)
		bannerToken += 1
		local token = bannerToken
		bannerTitle.Text = `WAVE {wave}`
		bannerTitle.TextColor3 = boss and Color3.fromRGB(235, 80, 66) or Color3.fromRGB(240, 232, 214)
		bannerSub.Text = boss and "BOSS WAVE" or ""
		banner.GroupTransparency = 1
		bannerScale.Scale = 1.35
		TweenService:Create(banner, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
		TweenService:Create(bannerScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if boss then
			Sfx.play("AlertTank", 0.5)
		end
		task.delay(1.9, function()
			if token == bannerToken then
				TweenService:Create(banner, TweenInfo.new(0.6), { GroupTransparency = 1 }):Play()
			end
		end)
	end

	local function hidden()
		local state = player:GetAttribute("State")
		return state == "Downed" or state == "Dead" -- la tarjeta de caído y la del espectador ocupan ese sitio
	end

	local function refresh()
		local stage = workspace:GetAttribute("Stage")
		local active = workspace:GetAttribute("MapId") == "Survival" and (stage == "Wave" or stage == "WaveBreak") and not hidden()
		panel.Visible = active
		if not active then
			return
		end
		local wave = workspace:GetAttribute("Wave") or 0
		if stage == "Wave" then
			local total = math.max(1, workspace:GetAttribute("WaveTotal") or 1)
			local left = math.clamp(workspace:GetAttribute("WaveLeft") or total, 0, total)
			local boss = workspace:GetAttribute("WaveBoss") == true
			title.Text = `WAVE {wave}`
			title.TextColor3 = boss and Paper.Red or Paper.Ink
			status.Text = boss and `BOSS WAVE · {left} LEFT` or `{left} LEFT`
			status.TextColor3 = boss and Paper.Red or Paper.Soft
			fill.Size = UDim2.fromScale(1 - left / total, 1)
			track.Visible = true
		else
			local remaining = math.max(0, (workspace:GetAttribute("WaveBreakEnd") or 0) - workspace:GetServerTimeNow())
			title.Text = wave == 0 and "GET READY" or `WAVE {wave} CLEARED`
			title.TextColor3 = Paper.Green
			status.Text = `NEXT WAVE IN {math.ceil(remaining)}`
			status.TextColor3 = Paper.Soft
			track.Visible = false
		end
	end

	local lastWave = 0
	workspace:GetAttributeChangedSignal("Wave"):Connect(function()
		local wave = workspace:GetAttribute("Wave") or 0
		if wave > 0 and wave ~= lastWave and workspace:GetAttribute("MapId") == "Survival" then
			showBanner(wave, workspace:GetAttribute("WaveBoss") == true)
		end
		lastWave = wave
		refresh()
	end)
	for _, name in { "Stage", "MapId", "WaveLeft", "WaveTotal", "WaveBoss" } do
		workspace:GetAttributeChangedSignal(name):Connect(refresh)
	end
	player:GetAttributeChangedSignal("State"):Connect(refresh)
	task.spawn(function()
		while true do
			if workspace:GetAttribute("Stage") == "WaveBreak" then
				refresh() -- la cuenta atrás de la pausa
			end
			task.wait(0.25)
		end
	end)
	refresh()
end

return WaveHud
