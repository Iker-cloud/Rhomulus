-- ¿Este jugador ya vio la tarjeta de bienvenida del lobby? Se guarda por jugador con DataStore (una sola vez en la vida).
-- Atributos del jugador que lee client/HelpPanel: HelpReady (ya se consultó el guardado) y HelpSeen (true = ya la vio).
-- Si el guardado no está disponible (por ejemplo en Studio sin acceso a los servicios de API) se trata como "no la ha visto"
-- y solo se recuerda mientras el jugador siga en el servidor.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimit = require(script.Parent.RateLimit)

local HelpState = {}

local KEY_PREFIX = "help_seen_"

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("RhomulusPlayerFlags")
	end)
	if ok then
		store = result
	end
end

local function load(player)
	local seen = false
	if store then
		local ok, value = pcall(function()
			return store:GetAsync(KEY_PREFIX .. player.UserId)
		end)
		seen = ok and value == true
	end
	if player.Parent == Players then
		player:SetAttribute("HelpSeen", seen)
		player:SetAttribute("HelpReady", true)
	end
end

function HelpState.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	-- El cliente avisa al cerrar la bienvenida
	Remotes.HelpSeen.OnServerEvent:Connect(function(player)
		if not RateLimit.check(player, "HelpSeen", 1) then
			return
		end
		if player:GetAttribute("HelpSeen") then
			return
		end
		player:SetAttribute("HelpSeen", true)
		if store then
			task.spawn(function()
				pcall(function()
					store:SetAsync(KEY_PREFIX .. player.UserId, true)
				end)
			end)
		end
	end)
end

return HelpState
