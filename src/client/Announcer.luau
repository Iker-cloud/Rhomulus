-- Megafonía del aeropuerto (cliente): cada cierto tiempo suena un timbre por el altavoz más cercano (piezas con la etiqueta
-- "PaSpeaker" que pone el constructor del mapa) y el aviso sale escrito unos segundos, como un subtítulo con forma de cartel de
-- aeropuerto (amarillo y negro). Solo en los mapas con avisos en Config.Announcer.Maps (o su arena de Survival, Config.MapTheme),
-- en las etapas de Config.Announcer.Stages y con un altavoz cerca. Los avisos están en inglés; Lang.watch los traduce.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local UiFit = require(script.Parent.UiFit)

local player = Players.LocalPlayer
local A = Config.Announcer

local Announcer = {}

local BLACK = Color3.fromRGB(22, 22, 24)
local YELLOW = Color3.fromRGB(242, 194, 48)
local CREAM = Color3.fromRGB(245, 245, 235)
local FADE = 0.35

local function lines()
	local id = workspace:GetAttribute("MapId")
	return id and (A.Maps[id] or A.Maps[Config.MapTheme[id] or ""]) or nil
end

local function nearestSpeaker()
	local camera = workspace.CurrentCamera
	local best, bestDistance = nil, A.SpeakerRange
	for _, speaker in CollectionService:GetTagged("PaSpeaker") do
		local distance = (speaker.Position - camera.CFrame.Position).Magnitude
		if distance < bestDistance then
			best, bestDistance = speaker, distance
		end
	end
	return best
end

function Announcer.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Announcer"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	local plate = Instance.new("CanvasGroup")
	plate.AnchorPoint = Vector2.new(0.5, 0)
	plate.Position = UDim2.new(0.5, 0, 0, 176) -- bajo el panel de la radio
	plate.Size = UDim2.fromOffset(620, 40)
	plate.BackgroundColor3 = BLACK
	plate.BackgroundTransparency = 0.15
	plate.BorderSizePixel = 0
	plate.GroupTransparency = 1
	plate.Visible = false
	plate.Parent = gui
	UiFit.scale(plate, 0.9)

	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.fromOffset(76, 40)
	tag.BackgroundColor3 = YELLOW
	tag.BorderSizePixel = 0
	tag.Font = Enum.Font.Oswald
	tag.TextSize = 22
	tag.TextScaled = true
	tag.TextColor3 = BLACK
	tag.Text = "PA"
	tag.Parent = plate

	local text = Instance.new("TextLabel")
	text.Position = UDim2.fromOffset(88, 0)
	text.Size = UDim2.new(1, -100, 1, 0)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Oswald
	text.TextSize = 19
	text.TextColor3 = CREAM
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextScaled = true
	text.Text = ""
	text.Parent = plate
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 19
	limit.MinTextSize = 9
	limit.Parent = text

	local shownAt = nil
	RunService.Heartbeat:Connect(function()
		if not shownAt then
			return
		end
		local t = os.clock() - shownAt
		local state = player:GetAttribute("State")
		if t >= A.ShowTime or state == "Downed" or state == "Dead" or workspace:GetAttribute("Stage") == "Result" then
			shownAt = nil
			plate.Visible = false
			plate.GroupTransparency = 1
			return
		end
		plate.Visible = true
		plate.GroupTransparency = math.clamp(math.max(1 - t / FADE, (t - (A.ShowTime - FADE)) / FADE), 0, 1)
	end)

	local function announce(line)
		local speaker = nearestSpeaker()
		if not speaker then
			return false
		end
		local chime = Instance.new("Sound")
		chime.SoundId = Config.Sounds.Announcer.Chime
		chime.Volume = A.Volume
		chime.RollOffMinDistance = 30
		chime.RollOffMaxDistance = A.SpeakerRange * 1.5
		chime.Parent = speaker
		local echo = Instance.new("ReverbSoundEffect") -- eco de sala grande
		echo.DecayTime = 2.2
		echo.WetLevel = -4
		echo.Parent = chime
		chime:Play()
		chime.Ended:Once(function()
			chime:Destroy()
		end)
		task.delay(12, function()
			chime:Destroy()
		end)
		text.Text = line
		shownAt = os.clock()
		return true
	end
	Announcer.announce = announce -- (para las pruebas)

	task.spawn(function()
		local last = nil
		while true do
			task.wait(A.MinInterval + math.random() * (A.MaxInterval - A.MinInterval))
			local list = lines()
			if list and A.Stages[workspace:GetAttribute("Stage")] then
				local line
				repeat
					line = list[math.random(#list)]
				until line ~= last or #list < 2
				if announce(line) then
					last = line
				end
			end
		end
	end)
end

return Announcer
