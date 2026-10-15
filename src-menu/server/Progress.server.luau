-- Lee el XP guardado del jugador (lo reparte y guarda la partida, server/PlayerProgress) y lo deja en sus atributos para que el menú
-- muestre el nivel: ProgXP (XP total) y ProgLevel. Solo lee; no guarda nada. Sin guardado (Studio sin publicar) no pone nada.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progress = require(ReplicatedStorage.Shared.Progress)

local ok, store = pcall(function()
	return DataStoreService:GetDataStore("RhomulusProgress")
end)
if not ok then
	return
end

local function load(player)
	local total = 0
	local readOk, value = pcall(function()
		return store:GetAsync("p_" .. player.UserId)
	end)
	if readOk and typeof(value) == "table" and typeof(value.xp) == "number" then
		total = value.xp
	end
	if player.Parent == Players then
		player:SetAttribute("ProgXP", total)
		player:SetAttribute("ProgLevel", (Progress.fromTotal(total)))
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(load, player)
end)
for _, player in Players:GetPlayers() do
	task.spawn(load, player)
end
