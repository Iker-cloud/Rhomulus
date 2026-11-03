-- Revivir (mantener E), cargar al caído en hombros (mantener F, soltar con G) y frases en globo.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerState = require(script.Parent.PlayerState)
local RateLimit = require(script.Parent.RateLimit)
local SkillCheck = require(script.Parent.SkillCheck)
local Points = require(script.Parent.Points)
local Stats = require(script.Parent.Stats)

local Revive = {}

local carrying = {} -- [carrier] = target
local carriedBy = {} -- [target] = carrier
local sessions = {} -- [helper] = { target, checks pasadas, falló } mientras mantiene E con las pruebas de acción activas

pcall(function()
	PhysicsService:RegisterCollisionGroup("Carried")
end)
PhysicsService:CollisionGroupSetCollidable("Carried", "Default", false)

local function say(character, text)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("Bubble")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(260, 40)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)

	gui.Parent = head
	Debris:AddItem(gui, Config.Revive.BubbleTime)
end

local function randomOf(list)
	return list[math.random(#list)]
end

local function getRoot(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function updatePrompts(player)
	local root = getRoot(player)
	if not root then
		return
	end
	local enabled = PlayerState.get(player) == "Downed" and not carriedBy[player]
	for _, name in { "RevivePrompt", "CarryPrompt" } do
		local prompt = root:FindFirstChild(name)
		if prompt then
			prompt.Enabled = enabled
		end
	end
end

local function setCollisionGroup(character, group)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = group
		end
	end
end

-- `reason` (opcional): por qué se soltó solo, para avisar a quien cargaba (si no, parece que el juego lo soltó sin motivo)
local function drop(carrier, reason)
	local target = carrying[carrier]
	if not target then
		return
	end
	carrying[carrier] = nil
	carriedBy[target] = nil

	carrier:SetAttribute("Carrying", nil)
	PlayerState.refreshSpeed(carrier)
	if typeof(reason) == "string" and carrier.Parent then
		Remotes.Feed:FireClient(carrier, reason)
	end

	local character = target.Character
	if character then
		character:SetAttribute("Carried", nil)
		character:SetAttribute("CarriedBy", nil)
		CollectionService:RemoveTag(character, "CarriedBody")
		setCollisionGroup(character, "Default")
		local droppedRoot = character:FindFirstChild("HumanoidRootPart")
		if droppedRoot then
			droppedRoot.Anchored = false
			droppedRoot.AssemblyLinearVelocity = Vector3.zero
			pcall(function()
				droppedRoot:SetNetworkOwner(target)
			end)
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
		end
		local carrierRoot = getRoot(carrier)
		if carrierRoot then
			character:PivotTo(CFrame.new(carrierRoot.Position + carrierRoot.CFrame.LookVector * 4))
		end
	end
	updatePrompts(target)
end

local function carry(carrier, target)
	local carrierRoot, targetRoot = getRoot(carrier), getRoot(target)
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if not (carrierRoot and targetRoot and humanoid) then
		return
	end

	carrying[carrier] = target
	carriedBy[target] = carrier
	Points.add(Config.Points.Carry, carrier)
	Stats.add(carrier, "Carries")
	carrier:SetAttribute("Carrying", target.Name)
	PlayerState.refreshSpeed(carrier)

	-- El cuerpo del caído queda anclado (lo mueve el servidor y cada cliente lo pega a quien carga, ver client/CarryAttach): sin
	-- soldaduras ni dueños de la física que se peleen entre el cliente del caído y el de quien carga
	target.Character:SetAttribute("Carried", true) -- el cliente deja de girar al personaje
	target.Character:SetAttribute("CarriedBy", carrier.Name)
	CollectionService:AddTag(target.Character, "CarriedBody")
	setCollisionGroup(target.Character, "Carried")
	humanoid.PlatformStand = true
	targetRoot.AssemblyLinearVelocity = Vector3.zero
	targetRoot.Anchored = true
	targetRoot.CFrame = carrierRoot.CFrame * Config.Revive.CarryOffset

	updatePrompts(target)
end

-- ¿Puede `helper` revivir o cargar a `target`? Devuelve (true) o (false, motivo en español)
local function canHelp(helper, target)
	if helper == target then
		return false, "no puedes cargarte a ti mismo"
	end
	if PlayerState.get(helper) ~= "Normal" then
		return false, "tienes que estar de pie"
	end
	if carrying[helper] or helper:GetAttribute("Carrying") then
		return false, "ya llevas algo a cuestas (G para soltar)"
	end
	if PlayerState.get(target) ~= "Downed" then
		return false, "ya no está caído"
	end
	if carriedBy[target] then
		return false, "ya lo está cargando otro"
	end
	local helperRoot, targetRoot = getRoot(helper), getRoot(target)
	if not (helperRoot and targetRoot) then
		return false, "no se encuentra a tu compañero"
	end
	if (helperRoot.Position - targetRoot.Position).Magnitude > Config.Revive.MaxDistance then
		return false, "estás muy lejos"
	end
	return true
end

-- Avisa en pantalla a quien intentó cargar y no pudo (si no, el prompt parece no hacer nada)
local function refuse(helper, reason)
	Remotes.Feed:FireClient(helper, `No puedes cargar: {reason}`)
end

local function makePrompt(root, name, action, key, holdTime, offset)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.KeyboardKeyCode = key
	prompt.HoldDuration = holdTime
	prompt.MaxActivationDistance = Config.Revive.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = offset
	prompt.Style = Enum.ProximityPromptStyle.Custom -- la interfaz la dibuja PromptUi.luau
	prompt.Enabled = false
	prompt.Parent = root
	return prompt
end

local function onCharacter(player, character)
	local root = character:WaitForChild("HumanoidRootPart")
	-- Si por algún motivo se llama dos veces con el mismo personaje, no se duplican los prompts
	for _, name in { "RevivePrompt", "CarryPrompt" } do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	local revivePrompt = makePrompt(root, "RevivePrompt", "Revivir", Enum.KeyCode.E, Config.Revive.HoldTime, Vector2.zero)
	local carryPrompt = makePrompt(root, "CarryPrompt", "Cargar", Enum.KeyCode.F, Config.Revive.CarryHoldTime, Vector2.new(0, 70))

	revivePrompt.ObjectText = player.DisplayName
	-- E y F tienen el mismo botón de mando por defecto: sin esto, con mando solo saldría uno de los dos
	carryPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	carryPrompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow

	-- Mientras mantiene E, quien revive lleva este atributo (hora en que terminaría); el cliente lo usa para arrodillarlo
	local function setReviving(helper, on)
		if helper.Character then
			helper.Character:SetAttribute("Reviving", on and workspace:GetServerTimeNow() + Config.Revive.HoldTime + 0.5 or nil)
		end
	end

	revivePrompt.PromptButtonHoldEnded:Connect(function(helper)
		setReviving(helper, false)
		local session = sessions[helper]
		if session then
			session.ended = true
			Remotes.SkillCheck:FireClient(helper, "cancel")
			-- Un momento de gracia: al completarse el hold puede soltar antes de que llegue Triggered
			task.delay(0.3, function()
				if sessions[helper] == session then
					sessions[helper] = nil
				end
			end)
		end
	end)

	-- Falla una prueba: se cancela el revivir (el prompt se apaga un momento y hay que volver a empezar)
	local function failSession(helper, session)
		if session.failed then
			return
		end
		session.failed = true
		Remotes.SkillCheck:FireClient(helper, "result", false)
		setReviving(helper, false)
		say(helper.Character, randomOf(Config.SkillCheck.FailPhrases))
		revivePrompt.Enabled = false
		task.delay(Config.SkillCheck.RetryDelay, function()
			sessions[helper] = nil
			updatePrompts(player)
		end)
	end

	revivePrompt.PromptButtonHoldBegan:Connect(function(helper)
		if not canHelp(helper, player) then
			return
		end
		setReviving(helper, true)
		if Config.SkillCheck.Enabled then
			local session = { target = player, passed = 0, failed = false, check = nil }
			sessions[helper] = session
			session.fail = function()
				failSession(helper, session)
			end
			for index, fraction in Config.SkillCheck.Times do
				task.delay(fraction * Config.Revive.HoldTime, function()
					if sessions[helper] ~= session or session.failed or session.ended then
						return
					end
					if not canHelp(helper, player) then
						Remotes.SkillCheck:FireClient(helper, "cancel") -- se alejó o cambió de estado: se quita el aro
						return
					end
					if session.check and not session.check.done then
						session.check.done = true
						session.fail() -- no pulsó la anterior
						return
					end
					local check = SkillCheck.new(Config.SkillCheck, workspace:GetServerTimeNow(), index)
					session.check = check
					Remotes.SkillCheck:FireClient(helper, "start", check.id, check.start, check.period, check.zoneStart, check.zoneSize)
					-- Si no pulsa a tiempo, falla
					task.delay(Config.SkillCheck.Delay + check.period + Config.SkillCheck.Tolerance + 0.3, function()
						if sessions[helper] == session and session.check == check and not check.done then
							check.done = true
							session.fail()
						end
					end)
				end)
			end
		end
		say(helper.Character, randomOf(Config.Revive.ReviverPhrases))
		task.delay(Config.Revive.ReplyDelay, function()
			if PlayerState.get(player) == "Downed" then
				say(player.Character, randomOf(Config.Revive.DownedPhrases))
			end
		end)
	end)

	revivePrompt.Triggered:Connect(function(helper)
		setReviving(helper, false)
		if Config.SkillCheck.Enabled then
			local session = sessions[helper]
			sessions[helper] = nil
			-- Solo se revive si superó todas las pruebas de esta pasada
			if not session or session.failed or session.passed < #Config.SkillCheck.Times then
				return
			end
		end
		if canHelp(helper, player) then
			PlayerState.revive(player, helper)
		end
	end)

	carryPrompt.Triggered:Connect(function(helper)
		local ok, reason = canHelp(helper, player)
		if ok then
			carry(helper, player)
		else
			refuse(helper, reason)
		end
	end)

	updatePrompts(player)
end

-- A quién carga `carrier` (nil si a nadie) y soltarlo: los usa server/Boarding al subir a la furgoneta con un caído a cuestas
function Revive.carriedBy(carrier)
	return carrying[carrier]
end
Revive.drop = drop

function Revive.start()
	local function setup(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		drop(player)
		if carriedBy[player] then
			drop(carriedBy[player])
		end
	end)

	PlayerState.Changed.Event:Connect(function(player, state)
		if carrying[player] and state ~= "Normal" then
			drop(player)
		end
		if carriedBy[player] and state ~= "Downed" then
			drop(carriedBy[player])
		end
		updatePrompts(player)
	end)

	local dropOnRequest = RateLimit.wrap("DropCarry", 0.3, function(carrier)
		drop(carrier) -- sin motivo: lo pidió el jugador (el cliente no puede mandar texto)
	end)
	Remotes.Drop.OnServerEvent:Connect(dropOnRequest)

	-- Si alguien reaparece (nuevo personaje) o su personaje desaparece, nada de lo que cargaba o de quien lo cargaba sigue valiendo:
	-- sin esto quedaba el registro viejo, el compañero pegado al cuerpo anterior y su prompt de cargar apagado para siempre
	local function release(player)
		drop(player)
		local carrier = carriedBy[player]
		if carrier then
			drop(carrier, `Soltaste a {player.DisplayName}: su personaje cambió`)
		end
	end
	-- Con el personaje nuevo ya puesto solo se borra el registro (no se toca el cuerpo: está apareciendo y soltarlo lo movería o lo desanclaría)
	local function forget(player)
		local target = carrying[player]
		if target then
			carrying[player] = nil
			carriedBy[target] = nil
		end
		local carrier = carriedBy[player]
		if carrier then
			carriedBy[player] = nil
			carrying[carrier] = nil
			carrier:SetAttribute("Carrying", nil)
			PlayerState.refreshSpeed(carrier)
		end
		updatePrompts(player) -- el prompt de cargar del personaje nuevo puede haber quedado apagado por el registro viejo
	end
	local function watchCharacterChanges(player)
		player.CharacterRemoving:Connect(function()
			release(player)
		end)
		player.CharacterAdded:Connect(function()
			forget(player)
		end)
	end
	Players.PlayerAdded:Connect(watchCharacterChanges)
	for _, player in Players:GetPlayers() do
		watchCharacterChanges(player)
	end

	-- El caído a cuestas sigue a quien lo carga (en el servidor, para que la zona, la furgoneta y los demás sistemas lo vean donde está)
	RunService.Heartbeat:Connect(function()
		for carrier, target in carrying do
			local carrierRoot, targetRoot = getRoot(carrier), getRoot(target)
			if not (carrierRoot and targetRoot and targetRoot:IsDescendantOf(workspace)) then
				drop(carrier, "Soltaste a tu compañero: ya no se encuentra")
			elseif carrier.Character ~= carrierRoot.Parent or target.Character ~= targetRoot.Parent then
				drop(carrier, "Soltaste a tu compañero: su personaje cambió")
			else
				targetRoot.CFrame = carrierRoot.CFrame * Config.Revive.CarryOffset
			end
		end
	end)

	-- Pulsación de la prueba de acción: el servidor decide con la hora que dice el cliente (ya limitada por SkillCheck.judge)
	Remotes.SkillCheckPress.OnServerEvent:Connect(function(helper, id, pressTime)
		if not RateLimit.check(helper, "SkillCheckPress", 0.1) then
			return
		end
		local session = sessions[helper]
		local check = session and session.check
		if not session then
			Remotes.SkillCheck:FireClient(helper, "cancel") -- la sesión ya se cerró: que el cliente quite el aro
			return
		end
		if not check or check.done or typeof(id) ~= "number" or typeof(pressTime) ~= "number" or check.id ~= id then
			return
		end
		check.done = true
		if SkillCheck.judge(check, pressTime, workspace:GetServerTimeNow(), Config.SkillCheck) then
			session.passed += 1
			Remotes.SkillCheck:FireClient(helper, "result", true)
		else
			session.fail()
		end
	end)
end

return Revive
