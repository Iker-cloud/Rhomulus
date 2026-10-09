-- Estado del equipo: panel de compañeros, marcador sobre los caídos, avisos propios y soltar con G.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DownedHud = require(script.Parent.DownedHud)

local player = Players.LocalPlayer

local TeamHud = {}

local function bleedRemaining(target)
	local bleedEnd = target:GetAttribute("BleedEnd")
	return bleedEnd and math.max(0, bleedEnd - workspace:GetServerTimeNow()) or 0
end

local function makeRow(parent)
	local row = Instance.new("Frame")
	row.Size = UDim2.fromOffset(220, 36)
	row.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	row.BackgroundTransparency = 0.4
	row.BorderSizePixel = 0
	row.Parent = parent

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(6, 0)
	name.Size = UDim2.new(1, -12, 0, 20)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 14
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = row

	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 6, 1, -12)
	back.Size = UDim2.new(1, -12, 0, 6)
	back.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
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
	text.Text = "▼ CAÍDO"
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

	-- Levantarse solo (1 jugador): mantener H unos segundos
	local selfReviveStart = nil
	local function canSelfRevive()
		return (player:GetAttribute("State") or "Normal") == "Downed"
			and #Players:GetPlayers() == 1
			and (player:GetAttribute("SelfRevives") or 0) > 0
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.G then
			Remotes.Drop:FireServer()
		elseif input.KeyCode == Enum.KeyCode.H and canSelfRevive() then
			selfReviveStart = os.clock()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.H then
			selfReviveStart = nil
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
					row.name.Text = `{other.DisplayName} — CAÍDO {math.ceil(remaining)}s`
					row.name.TextColor3 = Color3.fromRGB(255, 120, 60)
					row.fill.BackgroundColor3 = Color3.fromRGB(255, 140, 40)
					row.fill.Size = UDim2.fromScale(math.clamp(remaining / Config.Player.BleedTime, 0, 1), 1)
				elseif state == "Dead" then
					row.name.Text = `{other.DisplayName} — MUERTO`
					row.name.TextColor3 = Color3.fromRGB(150, 150, 150)
					row.fill.Size = UDim2.fromScale(0, 1)
				else
					row.name.TextColor3 = Color3.new(1, 1, 1)
					row.fill.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
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
			local hintText = "Un compañero puede revivirte"
			if player.Character and player.Character:GetAttribute("Carried") then
				hintText = "Te están cargando"
			elseif canSelfRevive() then
				if selfReviveStart then
					hintText = `Levantándote… {math.ceil(Config.Player.SelfReviveTime - (os.clock() - selfReviveStart))}s`
				else
					hintText = "Mantén H para levantarte"
				end
			end
			local remaining = bleedRemaining(player)
			downedCard.set(remaining, remaining / Config.Player.BleedTime, hintText)
			notice.Text = ""
		elseif carrying then
			downedCard.hide()
			local item = player:GetAttribute("CarryingItem") -- una garrafa (server/GasCans) en vez de un compañero
			notice.Text = item and `Cargando {item} — G para soltar` or `Cargando a {carrying} — G para soltar`
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
