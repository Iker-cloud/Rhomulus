-- Estado del equipo: panel de compañeros, marcador sobre los caídos, avisos propios y soltar con G.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DownedHud = require(script.Parent.DownedHud)
local Controls = require(script.Parent.Controls)

local UiFit = require(script.Parent.UiFit)
local Paper = require(script.Parent.PaperStyle)
local player = Players.LocalPlayer

local TeamHud = {}

local selfReviveStart = nil -- cuándo empezó a mantener H (o el botón de levantarse en celular)

-- Levantarse solo (1 jugador): mantener H unos segundos
local function canSelfRevive()
	return (player:GetAttribute("State") or "Normal") == "Downed"
		and #Players:GetPlayers() == 1
		and (player:GetAttribute("SelfRevives") or 0) > 0
end

function TeamHud.canSelfRevive()
	return canSelfRevive()
end

function TeamHud.beginSelfRevive()
	if canSelfRevive() then
		selfReviveStart = os.clock()
	end
end

function TeamHud.endSelfRevive()
	selfReviveStart = nil
end

function TeamHud.drop()
	Remotes.Drop:FireServer()
end

local function bleedRemaining(target)
	local bleedEnd = target:GetAttribute("BleedEnd")
	return bleedEnd and math.max(0, bleedEnd - workspace:GetServerTimeNow()) or 0
end

local function makeRow(parent)
	local row = Instance.new("Frame")
	row.Size = UDim2.fromOffset(220, 36)
	row.Parent = parent
	Paper.paper(row, 2)

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(6, 0)
	name.Size = UDim2.new(1, -12, 0, 20)
	name.FontFace = Paper.Head
	name.TextSize = 14
	name.TextColor3 = Paper.Ink
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = row

	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 6, 1, -12)
	back.Size = UDim2.new(1, -12, 0, 6)
	back.BackgroundColor3 = Color3.fromRGB(184, 168, 132)
	back.BorderSizePixel = 0
	back.Parent = row

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = back

	return { frame = row, name = name, fill = fill }
end

local function makeMarker(gui, target)
	local head = target.Character and target.Character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local marker = Instance.new("BillboardGui")
	marker.Adornee = head
	marker.Size = UDim2.fromOffset(110, 30)
	marker.StudsOffset = Vector3.new(0, 4.5, 0)
	marker.AlwaysOnTop = true
	marker.MaxDistance = 1000

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 70, 70)
	text.TextStrokeTransparency = 0.3
	text.Text = "▼ DOWN"
	text.Parent = marker

	marker.Parent = gui
	return marker
end

function TeamHud.start()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "TeamHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.BackgroundTransparency = 1
	panel.Position = UDim2.fromOffset(20, 76) -- debajo de la barra superior de Roblox (menú y chat)
	panel.Size = UDim2.fromOffset(220, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Parent = gui
	UiFit.scale(panel)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel

	local notice = Instance.new("TextLabel")
	notice.AnchorPoint = Vector2.new(0.5, 0)
	notice.Position = UDim2.new(0.5, 0, 0, 40)
	notice.Size = UDim2.fromOffset(500, 36)
	notice.BackgroundTransparency = 1
	notice.Font = Enum.Font.GothamBold
	notice.TextSize = 26
	notice.TextColor3 = Color3.fromRGB(255, 90, 90)
	notice.TextStrokeTransparency = 0.4
	notice.Parent = gui

	local rows, markers = {}, {}
	local downedCard = DownedHud.create(gui)

	-- Los prompts de revivir/cargar de tu propio cuerpo no se muestran
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if player.Character and prompt:IsDescendantOf(player.Character) then
			prompt.Enabled = false
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.G then
			TeamHud.drop()
		elseif input.KeyCode == Enum.KeyCode.H then
			TeamHud.beginSelfRevive()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.H then
			TeamHud.endSelfRevive()
		end
	end)
	RunService.Heartbeat:Connect(function()
		if selfReviveStart and canSelfRevive() and os.clock() - selfReviveStart >= Config.Player.SelfReviveTime then
			selfReviveStart = nil
			Remotes.SelfRevive:FireServer()
		end
	end)

	local function refresh()
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local row = rows[other]
				if not row then
					row = makeRow(panel)
					rows[other] = row
				end

				local state = other:GetAttribute("State") or "Normal"
				local humanoid = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
				row.name.Text = other.DisplayName
				if state == "Downed" then
					local remaining = bleedRemaining(other)
					row.name.Text = `{other.DisplayName} — DOWN {math.ceil(remaining)}s`
					row.name.TextColor3 = Color3.fromRGB(168, 70, 20)
					row.fill.BackgroundColor3 = Color3.fromRGB(226, 120, 30)
					row.fill.Size = UDim2.fromScale(math.clamp(remaining / Config.Player.BleedTime, 0, 1), 1)
				elseif state == "Dead" then
					row.name.Text = `{other.DisplayName} — DEAD`
					row.name.TextColor3 = Paper.Soft
					row.fill.Size = UDim2.fromScale(0, 1)
				else
					row.name.TextColor3 = Paper.Ink
					row.fill.BackgroundColor3 = Color3.fromRGB(176, 48, 44)
					local ratio = humanoid and humanoid.Health / humanoid.MaxHealth or 0
					row.fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
				end

				-- Marcador visible a través de paredes sobre el compañero caído
				if state == "Downed" and not markers[other] then
					markers[other] = makeMarker(gui, other)
				elseif state ~= "Downed" and markers[other] then
					markers[other]:Destroy()
					markers[other] = nil
				end
			end
		end

		for other, row in rows do
			if not other.Parent then
				row.frame:Destroy()
				rows[other] = nil
				if markers[other] then
					markers[other]:Destroy()
					markers[other] = nil
				end
			end
		end

		-- Aviso propio
		local state = player:GetAttribute("State") or "Normal"
		local carrying = player:GetAttribute("Carrying")
		if state == "Downed" then
			-- Tarjeta compacta: segundos de sangre que quedan y qué hacer
			local hintText = "A teammate can revive you"
			if player.Character and player.Character:GetAttribute("Carried") then
				hintText = "You're being carried"
			elseif canSelfRevive() then
				if selfReviveStart then
					hintText = `Getting up… {math.ceil(Config.Player.SelfReviveTime - (os.clock() - selfReviveStart))}s`
				else
					hintText = Controls.isTouch() and "Hold the button to get up" or "Hold H to get up"
				end
			end
			local remaining = bleedRemaining(player)
			downedCard.set(remaining, remaining / Config.Player.BleedTime, hintText)
			notice.Text = ""
		elseif carrying then
			downedCard.hide()
			local item = player:GetAttribute("CarryingItem") -- una garrafa (server/GasCans) en vez de un compañero
			local dropKey = Controls.isTouch() and "the button" or "G"
				notice.Text = item and `Hauling {item} — {dropKey} to drop` or `Carrying {carrying} — {dropKey} to drop`
		else
			downedCard.hide()
			notice.Text = ""
		end
	end

	task.spawn(function()
		while true do
			refresh()
			task.wait(0.2)
		end
	end)
end

return TeamHud
