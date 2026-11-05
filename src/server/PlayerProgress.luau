-- Progresión del jugador entre partidas (XP y nivel), guardada por jugador con DataStore. El servidor calcula el XP con sus propias
-- estadísticas (Stats): nunca acepta un número del cliente. Se reparte al terminar la partida (PlayerProgress.award) y, si alguien se
-- va a mitad, se le da lo que llevaba sin los bonos de terminar o ganar.
-- Atributos del jugador que lee la interfaz: ProgXP (XP total), ProgLevel, Rhoms (la moneda permanente), FrameId y TitleId (el marco y
-- el título del perfil que lleva puestos), MeleeOwned ("Knife,Pan": las skins cuerpo a cuerpo que tiene) y MeleeSkin (la que lleva).
-- El menú los pone con su propio script (src-menu), que además guarda lo que elige y compra.
-- Si el guardado no está disponible (Studio sin publicar) todo funciona pero no se recuerda nada.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progress = require(ReplicatedStorage.Shared.Progress)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Accessories = require(ReplicatedStorage.Shared.Accessories)
local Mutators = require(ReplicatedStorage.Shared.Mutators)
local Missions = require(ReplicatedStorage.Shared.Missions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Difficulty = require(script.Parent.Difficulty)
local Stats = require(script.Parent.Stats)
local Awards = require(script.Parent.Awards)

local PlayerProgress = {}

local KEY_PREFIX = "p_"
local totals = {} -- [Player] = XP total (ya con lo repartido en esta sesión)
local rhoms = {} -- [Player] = Rhoms que tiene (ya con las de esta sesión)
local crates = {} -- [Player] = cajas Arsenal sin abrir (las abre el menú)
local cratesB = {} -- [Player] = cajas Barrio sin abrir
local worn = {} -- [Player] = { owned = {ids}, equipped = { [ranura] = id } }: accesorios (caja Barrio)
local look = {} -- [Player] = { frame, title }: el marco y el título que lleva puestos
local dailyState = {} -- [Player] = lo guardado de las misiones del día (shared/Missions)
local streakState = {} -- [Player] = { last, count }: la racha de días con misiones
local seen = {} -- [Player] = { [id de mutación] = true }: las mutaciones que ya le salieron alguna vez (dan XP único la primera vez)

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
	local level = (Progress.fromTotal(total))
	player:SetAttribute("ProgLevel", level)
	player:SetAttribute("Rhoms", rhoms[player] or 0)
	player:SetAttribute("Crates", crates[player] or 0)
	player:SetAttribute("CratesBarrio", cratesB[player] or 0)
	local acc = worn[player] or { owned = {}, equipped = {} }
	player:SetAttribute("AccOwned", table.concat(acc.owned, ","))
	player:SetAttribute("AccEquipped", Accessories.encode(acc.equipped)) -- server/AccessoryRig los pone en el personaje
	local chosen = look[player] or {}
	local owned = chosen.owned or {}
	player:SetAttribute("MeleeOwned", table.concat(owned, ","))
	player:SetAttribute("MeleeSkin", Cosmetics.validMelee(owned, chosen.melee)) -- server/Melee
	player:SetAttribute("FrameId", Cosmetics.valid("frame", chosen.frame, level))
	player:SetAttribute("TitleId", Cosmetics.valid("title", chosen.title, level))
	-- Misiones diarias: día, progreso y cuáles están hechas (el menú calcula cuáles son con Missions.pick)
	local today = Missions.today()
	local state = Missions.normalize(dailyState[player], today)
	player:SetAttribute("MissionDay", today)
	player:SetAttribute("MissionProg", table.concat(state.prog, ","))
	player:SetAttribute("MissionDone", (state.done[1] and "1" or "0") .. "," .. (state.done[2] and "1" or "0") .. "," .. (state.done[3] and "1" or "0"))
	player:SetAttribute("MissionStreak", Missions.streakCount(streakState[player], today))
	local ids = {}
	for id in seen[player] or {} do
		table.insert(ids, id)
	end
	player:SetAttribute("SeenMutators", table.concat(ids, ",")) -- la ruleta de mutaciones marca las que son nuevas para él
end

local function load(player)
	local total, coins, boxes, boxesB = 0, 0, 0, 0
	local accOwned, accEquipped = {}, {}
	local chosen
	if store then
		local ok, value = pcall(function()
			return store:GetAsync(KEY_PREFIX .. player.UserId)
		end)
		if ok and typeof(value) == "table" and typeof(value.xp) == "number" then
			total = value.xp
			coins = typeof(value.rhoms) == "number" and value.rhoms or 0
			boxes = typeof(value.crates) == "number" and value.crates or 0
			boxesB = typeof(value.crates_b) == "number" and value.crates_b or 0
			if typeof(value.acc) == "table" then
				for _, item in Accessories.Items do
					if value.acc[item.Id] == true then
						table.insert(accOwned, item.Id)
					end
				end
			end
			if typeof(value.accEq) == "table" then
				for slot, id in value.accEq do
					if typeof(id) == "string" and table.find(accOwned, id) then
						accEquipped[slot] = id
					end
				end
			end
			dailyState[player] = value.daily
			streakState[player] = value.streak
			chosen = { frame = value.frame, title = value.title, melee = value.melee, owned = {} }
			if typeof(value.skins) == "table" then
				for id, flag in value.skins do
					if flag == true and Cosmetics.melee(id) then
						table.insert(chosen.owned, id)
					end
				end
			end
			if typeof(value.seen) == "table" then
				seen[player] = {}
				for id, flag in value.seen do
					if flag == true and Mutators.isValid(id) then
						seen[player][id] = true
					end
				end
			end
		end
	end
	if player.Parent == Players then
		totals[player] = (totals[player] or 0) + total -- por si ya se le dio XP mientras cargaba
		rhoms[player] = (rhoms[player] or 0) + coins
		crates[player] = (crates[player] or 0) + boxes
		cratesB[player] = (cratesB[player] or 0) + boxesB
		worn[player] = { owned = accOwned, equipped = accEquipped }
		look[player] = chosen
		publish(player)
	end
end

-- Suma lo ganado en una partida a lo guardado (UpdateAsync: seguro aunque el menú u otro servidor lo lea a la vez)
local function save(userId, gained, stats, won, finished, discovered, coins, boxes, boxesB, daily, streak)
	if not store or (gained <= 0 and (coins or 0) <= 0 and (boxes or 0) <= 0 and (boxesB or 0) <= 0) then
		return
	end
	pcall(function()
		store:UpdateAsync(KEY_PREFIX .. userId, function(old)
			old = typeof(old) == "table" and old or {}
			old.xp = (old.xp or 0) + gained
			old.rhoms = (old.rhoms or 0) + (coins or 0)
			old.crates = (old.crates or 0) + (boxes or 0)
			old.crates_b = (old.crates_b or 0) + (boxesB or 0)
			old.games = (old.games or 0) + (finished and 1 or 0)
			old.wins = (old.wins or 0) + (won and finished and 1 or 0)
			old.kills = (old.kills or 0) + (stats.Kills or 0)
			old.revives = (old.revives or 0) + (stats.Revives or 0)
			if daily then
				old.daily = daily
				old.streak = streak
			end
			if discovered and #discovered > 0 then
				old.seen = typeof(old.seen) == "table" and old.seen or {}
				for _, id in discovered do
					old.seen[id] = true
				end
			end
			return old
		end)
	end)
end

-- Fin de la partida: reparte el XP a todos los que siguen en el servidor y le cuenta a todos lo de todos (Remotes.XpGain), para que la
-- pantalla de resultados muestre la barra de cada superviviente.
function PlayerProgress.award(won)
	local difficultyId = Difficulty.id()
	local bonus = Mutators.xpBonus(Difficulty.mutators())
	local list = {}
	local rarities = {}
	for _, id in Difficulty.mutators() do
		table.insert(rarities, Mutators[id] and Mutators[id].Rarity)
	end
	local rewarded = {} -- [userId] = true: quienes recibieron un reconocimiento
	for _, award in Awards.compute(Stats.all()) do
		for _, winner in award.winners do
			rewarded[winner.userId] = true
		end
	end
	for _, player in Players:GetPlayers() do
		local stats = Stats.get(player)
		local gained = Progress.roundXp(stats, won, true, difficultyId, bonus)
		-- XP único por cada mutación que le sale por primera vez
		local discovered = {}
		seen[player] = seen[player] or {}
		for _, id in Difficulty.mutators() do
			if not seen[player][id] then
				seen[player][id] = true
				table.insert(discovered, id)
				gained += Mutators.DiscoveryXp
			end
		end
		local coins = Progress.roundRhoms(won, true, difficultyId, rarities, rewarded[player.UserId])
		-- caja Arsenal de premio (a lo más una por ronda; la abre el menú)
		local dropped = math.random() < Cosmetics.crateDropChance(won, difficultyId, rarities)
		local kind = dropped and Cosmetics.crateKind(math.random()) or nil
		local box = kind == "Arsenal" and 1 or 0
		local boxB = kind == "Barrio" and 1 or 0
		-- Misiones diarias: lo de esta ronda se suma al progreso del día; las que se completan pagan Rhoms (y la racha, a veces un bono)
		local hard = difficultyId == "Crisis" or difficultyId == "Colapso"
		local state, newStreak, mission = Missions.apply(player.UserId, dailyState[player], streakState[player], Missions.today(), {
			kills = stats.Kills or 0,
			revives = stats.Revives or 0,
			carries = stats.Carries or 0,
			headshots = stats.Headshots or 0,
			games = 1,
			wins = won and 1 or 0,
			hardWins = (won and hard) and 1 or 0,
			cleanWins = (won and (stats.Downs or 0) == 0) and 1 or 0,
		})
		dailyState[player] = state
		streakState[player] = newStreak
		coins += mission.rhoms
		local before = totals[player] or 0
		totals[player] = before + gained
		rhoms[player] = (rhoms[player] or 0) + coins
		crates[player] = (crates[player] or 0) + box
		cratesB[player] = (cratesB[player] or 0) + boxB
		publish(player)
		table.insert(list, { userId = player.UserId, gained = gained, before = before, after = totals[player], rhoms = coins, crate = kind, missionRhoms = mission.rhoms, missions = mission.completed })
		task.spawn(save, player.UserId, gained, stats, won, true, discovered, coins, box, boxB, state, newStreak)
	end
	Remotes.XpGain:FireAllClients(list)
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
		local gained = Progress.roundXp(stats, false, false, Difficulty.id(), Mutators.xpBonus(Difficulty.mutators()))
		if gained > 0 then
			task.spawn(save, player.UserId, gained, stats, false, false)
		end
		totals[player] = nil
		rhoms[player] = nil
		crates[player] = nil
		cratesB[player] = nil
		worn[player] = nil
		look[player] = nil
		seen[player] = nil
		dailyState[player] = nil
		streakState[player] = nil
	end)
end

return PlayerProgress
