-- Estado del jugador: Normal, Caído (se desangra, puede disparar la pistola) o Muerto.
-- Todo daño a jugadores pasa por PlayerState.damage para poder convertir la muerte en caída.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Points = require(script.Parent.Points)
local Stats = require(script.Parent.Stats)

local PlayerState = {}

-- (player, newState)
PlayerState.Changed = Instance.new("BindableEvent")

local bleedTokens = {} -- [Player] = number, invalida desangrados anteriores
local safePoint = nil -- CFrame del último punto seguro; nil = aparición por defecto

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
	else
		humanoid.WalkSpeed = Config.Player.WalkSpeed
	end
end

function PlayerState.setSafePoint(cframe)
	safePoint = cframe
end

local function down(player, humanoid)
	humanoid.Health = 1
	setState(player, "Downed")
	PlayerState.refreshSpeed(player)

	local token = (bleedTokens[player] or 0) + 1
	bleedTokens[player] = token
	-- Hora del servidor en que muere; el cliente la usa para mostrar la cuenta regresiva
	player:SetAttribute("BleedEnd", workspace:GetServerTimeNow() + Config.Player.BleedTime)

	task.delay(Config.Player.BleedTime, function()
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
	if PlayerState.get(player) ~= "Normal" then
		return
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
		Points.add(Config.Points.Revive)
		Points.feed(`{helper.DisplayName} revivió a {player.DisplayName}`)
	end
end

local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	bleedTokens[player] = (bleedTokens[player] or 0) + 1
	player:SetAttribute("BleedEnd", nil)
	player:SetAttribute("Carrying", nil)
	setState(player, "Normal")
	PlayerState.refreshSpeed(player)

	if safePoint then
		character:WaitForChild("HumanoidRootPart")
		-- Dispersos para que no reaparezcan encimados
		character:PivotTo(safePoint * CFrame.new(math.random(-6, 6), 0, math.random(-6, 6)))
	end

	humanoid.Died:Once(function()
		bleedTokens[player] = (bleedTokens[player] or 0) + 1
		player:SetAttribute("BleedEnd", nil)
		setState(player, "Dead")
	end)
end

function PlayerState.start()
	local function setup(player)
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

	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		bleedTokens[player] = nil
	end)
end

return PlayerState
