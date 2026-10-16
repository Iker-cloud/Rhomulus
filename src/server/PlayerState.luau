-- Estado del jugador: Normal, Caído (se desangra, puede disparar la pistola) o Muerto.
-- Todo daño a jugadores pasa por PlayerState.damage para poder convertir la muerte en caída.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Difficulty = require(script.Parent.Difficulty)
local RateLimit = require(script.Parent.RateLimit)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Points = require(script.Parent.Points)
local Stats = require(script.Parent.Stats)
local Telemetry = require(script.Parent.Telemetry)

local PlayerState = {}

-- (player, newState)
PlayerState.Changed = Instance.new("BindableEvent")

local bleedTokens = {} -- [Player] = number, invalida desangrados anteriores
local sprinting = {} -- [Player] = true mientras mantiene Shift (lo dice el cliente; solo vale en estado Normal)
local safePoint = nil -- CFrame del último punto seguro; nil = aparición por defecto
local spawnOverride = {} -- [Player] = CFrame donde aparece la próxima vez (quien entra con la partida empezada: junto a un compañero)

local function getHumanoid(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function setState(player, state)
	player:SetAttribute("State", state)
	PlayerState.Changed:Fire(player, state)
end

function PlayerState.get(player)
	return player:GetAttribute("State") or "Normal"
end

function PlayerState.refreshSpeed(player)
	local humanoid = getHumanoid(player)
	if not humanoid then
		return
	end
	local state = PlayerState.get(player)
	if state == "Downed" then
		humanoid.WalkSpeed = Config.Player.DownedWalkSpeed
	elseif player:GetAttribute("Carrying") then
		humanoid.WalkSpeed = Config.Player.CarrySpeed
	elseif sprinting[player] then
		humanoid.WalkSpeed = Config.Player.SprintSpeed
	else
		humanoid.WalkSpeed = Config.Player.WalkSpeed
	end
end

function PlayerState.setSprinting(player, on)
	sprinting[player] = on or nil
	PlayerState.refreshSpeed(player)
end

-- Hace que el próximo personaje de `player` aparezca en `cframe` (una sola vez) en vez de en el punto seguro
function PlayerState.spawnAt(player, cframe)
	spawnOverride[player] = cframe
end

function PlayerState.setSafePoint(cframe)
	safePoint = cframe
end

local function down(player, humanoid)
	humanoid.Health = 1
	setState(player, "Downed")
	Telemetry.downed(player)
	PlayerState.refreshSpeed(player)

	local token = (bleedTokens[player] or 0) + 1
	bleedTokens[player] = token
	-- Hora del servidor en que muere; el cliente la usa para mostrar la cuenta regresiva
	local bleedTime = Config.Player.BleedTime * Difficulty.get().BleedTime
	player:SetAttribute("BleedEnd", workspace:GetServerTimeNow() + bleedTime)
	player:SetAttribute("DownedAt", workspace:GetServerTimeNow())

	task.delay(bleedTime, function()
		if bleedTokens[player] == token and PlayerState.get(player) == "Downed" then
			local current = getHumanoid(player)
			if current then
				current.Health = 0
			end
		end
	end)
end

-- Daño a un jugador (zombies, etc.). Si lo dejaría en 0, cae en vez de morir.
function PlayerState.damage(player, amount)
	if PlayerState.get(player) ~= "Normal" or player:GetAttribute("Boarded") or player:GetAttribute("Boarding") then
		return -- quien sube a la furgoneta (server/Boarding) ya está a salvo
	end
	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	Stats.add(player, "DamageTaken", math.min(amount, humanoid.Health))
	if humanoid.Health - amount <= 0 then
		down(player, humanoid)
	else
		humanoid:TakeDamage(amount)
	end
end

function PlayerState.revive(player, helper)
	if PlayerState.get(player) ~= "Downed" then
		return
	end
	local humanoid = getHumanoid(player)
	if not humanoid then
		return
	end
	bleedTokens[player] = (bleedTokens[player] or 0) + 1
	player:SetAttribute("BleedEnd", nil)
	humanoid.Health = Config.Player.ReviveHealth
	setState(player, "Normal")
	PlayerState.refreshSpeed(player)
	if helper then
		Stats.add(helper, "Revives")
		Points.add(Config.Points.Revive, helper)
		Points.feed(`{helper.DisplayName} revivió a {player.DisplayName}`)
	end
end

-- Con 1 solo jugador puede levantarse solo, una vez por zona
function PlayerState.selfRevive(player)
	if PlayerState.get(player) ~= "Downed" or #Players:GetPlayers() ~= 1 then
		return
	end
	local charges = player:GetAttribute("SelfRevives") or 0
	if charges <= 0 then
		return
	end
	local elapsed = workspace:GetServerTimeNow() - (player:GetAttribute("DownedAt") or 0)
	if elapsed < Config.Player.SelfReviveTime * 0.9 then
		return
	end
	player:SetAttribute("SelfRevives", charges - 1)
	PlayerState.revive(player)
	Points.feed(`{player.DisplayName} se levantó solo`)
end

-- Se llama al empezar cada zona
function PlayerState.resetSelfRevives()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("SelfRevives", Difficulty.get().SelfRevives)
	end
end

-- Deja el personaje quieto en `target` hasta que el cliente confirme que tiene suelo (Remotes.GroundReady) o pase el tiempo máximo
local function settle(player, character, root, target)
	root.Anchored = true
	character:PivotTo(target)
	character:SetAttribute("AwaitGround", true)
	pcall(function()
		player:RequestStreamAroundAsync(target.Position, 8)
	end)
	local deadline = os.clock() + Config.Player.SpawnGroundTimeout
	while character.Parent and character:GetAttribute("AwaitGround") and os.clock() < deadline do
		task.wait(0.1)
	end
	character:SetAttribute("AwaitGround", nil)
	task.wait(Config.Player.SpawnStreamWait) -- margen: que el cliente termine de colocar lo recibido antes de soltarlo
	if character.Parent and root.Parent then
		root.AssemblyLinearVelocity = Vector3.zero
		root.Anchored = false
	end
end

local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	local maxHealth = Difficulty.get().Flags.PlayerHealth -- mutador "Cristal"
	if maxHealth then
		humanoid.MaxHealth = maxHealth
		humanoid.Health = maxHealth
	end
	bleedTokens[player] = (bleedTokens[player] or 0) + 1
	player:SetAttribute("BleedEnd", nil)
	player:SetAttribute("Carrying", nil)
	setState(player, "Normal")
	PlayerState.refreshSpeed(player)

	humanoid.Died:Once(function()
		bleedTokens[player] = (bleedTokens[player] or 0) + 1
		player:SetAttribute("BleedEnd", nil)
		setState(player, "Dead")
		Telemetry.died(player)
	end)

	local base = spawnOverride[player] or safePoint
	spawnOverride[player] = nil
	if base then
		local root = character:WaitForChild("HumanoidRootPart")
		root.Anchored = true -- quieto desde el primer instante (antes de que cargue el avatar)
		-- Con StreamingEnabled el suelo del mapa recién construido tarda en llegar al cliente: se espera quieto a que cargue
		-- (si no, el personaje cae al vacío)
		local appearanceDeadline = os.clock() + 6
		while player.Parent and not player:HasAppearanceLoaded() and os.clock() < appearanceDeadline do
			task.wait(0.1)
		end
		if character.Parent and root.Parent then
			-- Dispersos para que no reaparezcan encimados
			settle(player, character, root, base * CFrame.new(math.random(-6, 6), 0, math.random(-6, 6)))
		end
	end
end

-- Red de seguridad: si alguien cae al vacío (suelo sin cargar, hueco del mapa...) se le devuelve al último punto seguro
local VOID_HEIGHT = -40
local rescuing = {}
local function rescue(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or rescuing[player] then
		return
	end
	rescuing[player] = true
	local target = safePoint and safePoint * CFrame.new(math.random(-6, 6), 2, math.random(-6, 6)) or CFrame.new(0, 10, -375)
	-- Mejor junto a un compañero que siga de pie
	for _, other in Players:GetPlayers() do
		local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if otherRoot and otherRoot.Position.Y > VOID_HEIGHT and PlayerState.get(other) == "Normal" then
			target = otherRoot.CFrame * CFrame.new(0, 3, 0)
			break
		end
	end
	settle(player, character, root, target)
	rescuing[player] = nil
end

function PlayerState.start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and not root.Anchored and root.Position.Y < VOID_HEIGHT and root.Position.Y > -300 then
					task.spawn(rescue, player)
				end
			end
		end
	end)
	local function setup(player)
		player:SetAttribute("SelfRevives", Difficulty.get().SelfRevives)
		-- Sin personaje hasta que la partida los haga aparecer
		if not player.Character then
			player:SetAttribute("State", "Dead")
		end
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end

	Remotes.GroundReady.OnServerEvent:Connect(function(player)
		if not RateLimit.check(player, "GroundReady", 0.1) then
			return
		end
		local character = player.Character
		if character and character:GetAttribute("AwaitGround") then
			character:SetAttribute("AwaitGround", nil)
		end
	end)
	Remotes.SelfRevive.OnServerEvent:Connect(RateLimit.wrap("SelfRevive", 0.3, PlayerState.selfRevive))
	Remotes.Sprint.OnServerEvent:Connect(function(player, on)
		if typeof(on) == "boolean" and RateLimit.check(player, "Sprint", 0.1) then
			PlayerState.setSprinting(player, on)
		end
	end)

	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		bleedTokens[player] = nil
		sprinting[player] = nil
	end)
end

return PlayerState
