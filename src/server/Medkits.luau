-- Botiquines: se recogen con E (cada jugador lleva uno como máximo, atributo HasMedkit) y se usan con la tecla de
-- Config.Medkit.Key: curan Config.Medkit.Heal de vida en Config.Medkit.Time segundos, a uno mismo o a un compañero
-- herido cercano. Mientras dura, el jugador tiene los atributos HealingEnd (hora del servidor) y HealingTarget (nombre
-- del curado, vacío si se cura a sí mismo) para el HUD (client/MedkitHud). Se interrumpe si alguien cae o se alejan.
-- MapBuilderBarrio pone los botiquines en refs.medkits: { { model = Model, prompt = ProximityPrompt }, ... }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerState = require(script.Parent.PlayerState)
local Points = require(script.Parent.Points)

local Medkits = {}

local M = Config.Medkit
local pickups = {}
local globalsConnected = false -- init se llama en cada mapa nuevo: los eventos globales se conectan una sola vez
local healing = {} -- [quien cura] = ficha de la curación en curso

local function getHumanoid(player)
	return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
end

local function getRoot(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function stopHealing(player)
	healing[player] = nil
	player:SetAttribute("HealingEnd", nil)
	player:SetAttribute("HealingTarget", nil)
end

-- ¿Se puede curar a `target` desde `player`? Devuelve el motivo si no.
local function denied(player, target)
	local humanoid = getHumanoid(target)
	if PlayerState.get(target) ~= "Normal" or not humanoid or humanoid.Health <= 0 then
		return "No se puede curar ahora"
	end
	if humanoid.Health >= humanoid.MaxHealth then
		return target == player and "Tienes la vida llena" or `{target.DisplayName} tiene la vida llena`
	end
	if target ~= player then
		local a, b = getRoot(player), getRoot(target)
		if not a or not b or (a.Position - b.Position).Magnitude > M.Range + 3 then
			return "Acércate más para curar"
		end
	end
	return nil
end

local function useMedkit(player, target)
	if healing[player] or not player:GetAttribute("HasMedkit") or PlayerState.get(player) ~= "Normal" then
		return
	end
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target.Parent ~= Players then
		target = player
	end
	local reason = denied(player, target)
	if reason then
		Remotes.Feed:FireClient(player, reason)
		return
	end

	local token = {}
	healing[player] = token
	local endTime = workspace:GetServerTimeNow() + M.Time
	player:SetAttribute("HealingEnd", endTime)
	player:SetAttribute("HealingTarget", target == player and "" or target.DisplayName)

	task.spawn(function()
		while workspace:GetServerTimeNow() < endTime do
			task.wait(0.1)
			if healing[player] ~= token then
				return
			end
			if PlayerState.get(player) ~= "Normal" or denied(player, target) then
				stopHealing(player)
				Remotes.Feed:FireClient(player, "Curación interrumpida")
				return
			end
		end
		stopHealing(player)
		local humanoid = getHumanoid(target)
		if humanoid then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + M.Heal)
		end
		player:SetAttribute("HasMedkit", false)
		Points.feed(target == player and `{player.DisplayName} se curó` or `{player.DisplayName} curó a {target.DisplayName}`)
	end)
end

function Medkits.init(list)
	pickups = list or {}
	for _, pickup in pickups do
		pickup.parent = pickup.model.Parent
		pickup.prompt.ActionText = "Tomar botiquín"
		pickup.prompt.ObjectText = `Cura {M.Heal}`
		pickup.prompt.HoldDuration = 0.3
		pickup.prompt.Triggered:Connect(function(player)
			if not pickup.model.Parent or PlayerState.get(player) ~= "Normal" then
				return
			end
			if player:GetAttribute("HasMedkit") then
				Remotes.Feed:FireClient(player, "Ya llevas un botiquín")
				return
			end
			pickup.prompt.Enabled = false
			pickup.model.Parent = nil
			player:SetAttribute("HasMedkit", true)
			Remotes.Feed:FireClient(player, `Botiquín: pulsa {M.KeyLabel} para curarte o curar al compañero que miras`)
		end)
	end

	if not globalsConnected then
		globalsConnected = true
		Remotes.UseMedkit.OnServerEvent:Connect(useMedkit)
		Players.PlayerRemoving:Connect(function(player)
			healing[player] = nil
		end)
	end
end

-- Al empezar cada partida: los botiquines vuelven a su sitio y nadie lleva uno
function Medkits.reset()
	for _, pickup in pickups do
		pickup.model.Parent = pickup.parent
		pickup.prompt.Enabled = true
	end
	for _, player in Players:GetPlayers() do
		stopHealing(player)
		player:SetAttribute("HasMedkit", false)
	end
end

return Medkits
