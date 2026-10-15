-- Progresión del jugador entre partidas (XP y nivel), guardada por jugador con DataStore. El servidor calcula el XP con sus propias
-- estadísticas (Stats): nunca acepta un número del cliente. Se reparte al terminar la partida (PlayerProgress.award) y, si alguien se
-- va a mitad, se le da lo que llevaba sin los bonos de terminar o ganar.
-- Atributos del jugador que lee la interfaz: ProgXP (XP total) y ProgLevel. El menú los pone con su propio script (src-menu).
-- Si el guardado no está disponible (Studio sin publicar) todo funciona pero no se recuerda nada.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progress = require(ReplicatedStorage.Shared.Progress)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Difficulty = require(script.Parent.Difficulty)
local Stats = require(script.Parent.Stats)

local PlayerProgress = {}

local KEY_PREFIX = "p_"
local totals = {} -- [Player] = XP total (ya con lo repartido en esta sesión)

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("RhomulusProgress")
	end)
	if ok then
		store = result
	end
end

local function publish(player)
	local total = totals[player] or 0
	player:SetAttribute("ProgXP", total)
	player:SetAttribute("ProgLevel", (Progress.fromTotal(total)))
end

local function load(player)
	local total = 0
	if store then
		local ok, value = pcall(function()
			return store:GetAsync(KEY_PREFIX .. player.UserId)
		end)
		if ok and typeof(value) == "table" and typeof(value.xp) == "number" then
			total = value.xp
		end
	end
	if player.Parent == Players then
		totals[player] = (totals[player] or 0) + total -- por si ya se le dio XP mientras cargaba
		publish(player)
	end
end

-- Suma lo ganado en una partida a lo guardado (UpdateAsync: seguro aunque el menú u otro servidor lo lea a la vez)
local function save(userId, gained, stats, won, finished)
	if not store or gained <= 0 then
		return
	end
	pcall(function()
		store:UpdateAsync(KEY_PREFIX .. userId, function(old)
			old = typeof(old) == "table" and old or {}
			old.xp = (old.xp or 0) + gained
			old.games = (old.games or 0) + (finished and 1 or 0)
			old.wins = (old.wins or 0) + (won and finished and 1 or 0)
			old.kills = (old.kills or 0) + (stats.Kills or 0)
			old.revives = (old.revives or 0) + (stats.Revives or 0)
			return old
		end)
	end)
end

-- Fin de la partida: reparte el XP a todos los que siguen en el servidor y se lo cuenta a cada uno (Remotes.XpGain).
function PlayerProgress.award(won)
	local difficultyId = Difficulty.id()
	for _, player in Players:GetPlayers() do
		local stats = Stats.get(player)
		local gained, parts = Progress.roundXp(stats, won, true, difficultyId)
		local before = totals[player] or 0
		totals[player] = before + gained
		publish(player)
		Remotes.XpGain:FireClient(player, gained, parts, before, totals[player])
		task.spawn(save, player.UserId, gained, stats, won, true)
	end
end

function PlayerProgress.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	-- Quien se va a mitad de la partida se lleva lo que hizo hasta ese momento, sin los bonos de terminar o ganar
	Players.PlayerRemoving:Connect(function(player)
		local stage = workspace:GetAttribute("Stage")
		if stage == nil or stage == "Vote" or stage == "Lobby" or stage == "Result" then
			return
		end
		local stats = Stats.get(player)
		local gained = Progress.roundXp(stats, false, false, Difficulty.id())
		if gained > 0 then
			task.spawn(save, player.UserId, gained, stats, false, false)
		end
		totals[player] = nil
	end)
end

return PlayerProgress
