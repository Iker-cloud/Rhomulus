-- Misiones diarias: 3 por día (una fácil, una media y una difícil), iguales para el jugador durante todo el día UTC. Se reinician a la
-- medianoche UTC. Pagan Rhoms (la moneda permanente) al terminar la ronda (server/PlayerProgress). Solo son datos y cuentas: la partida
-- mide el progreso con sus propias estadísticas y lo guarda en `daily` y `streak` de RhomulusProgress; el menú lo muestra.
-- Los textos van en inglés y se traducen solos (shared/LangEs). Los ids no se traducen.
local Missions = {}

Missions.SECONDS_PER_DAY = 86400

-- Cada misión: Id, Text (con {n} en lugar de la meta), Metric (qué se cuenta), Target y Rhoms que paga. `Tier` 1 fácil, 2 media, 3 difícil.
-- Métricas que cuenta la partida al terminar cada ronda: kills, revives, carries, headshots, games (rondas terminadas), wins (ganadas),
-- hardWins (ganadas en Crisis o Colapso) y cleanWins (ganadas sin caer ni una vez).
Missions.Pool = {
	{ Id = "Kills40", Tier = 1, Metric = "kills", Target = 40, Rhoms = 2, Text = "Kill {n} zombies" },
	{ Id = "Revive1", Tier = 1, Metric = "revives", Target = 1, Rhoms = 2, Text = "Revive a teammate" },
	{ Id = "Carry1", Tier = 1, Metric = "carries", Target = 1, Rhoms = 2, Text = "Carry a downed teammate" },
	{ Id = "Finish1", Tier = 1, Metric = "games", Target = 1, Rhoms = 2, Text = "Finish a round" },
	{ Id = "Kills100", Tier = 2, Metric = "kills", Target = 100, Rhoms = 2, Text = "Kill {n} zombies" },
	{ Id = "Heads15", Tier = 2, Metric = "headshots", Target = 15, Rhoms = 2, Text = "Land {n} headshots" },
	{ Id = "Revive3", Tier = 2, Metric = "revives", Target = 3, Rhoms = 2, Text = "Revive teammates {n} times" },
	{ Id = "Win1", Tier = 2, Metric = "wins", Target = 1, Rhoms = 2, Text = "Win a round" },
	{ Id = "Kills200", Tier = 3, Metric = "kills", Target = 200, Rhoms = 3, Text = "Kill {n} zombies" },
	{ Id = "Heads40", Tier = 3, Metric = "headshots", Target = 40, Rhoms = 3, Text = "Land {n} headshots" },
	{ Id = "HardWin", Tier = 3, Metric = "hardWins", Target = 1, Rhoms = 3, Text = "Win a round on Crisis or Collapse" },
	{ Id = "CleanWin", Tier = 3, Metric = "cleanWins", Target = 1, Rhoms = 3, Text = "Win without going down" },
}

-- Racha: días seguidos con al menos una misión completada. En el día 3 y en el 7 hay bono (el 7 reinicia la cuenta).
Missions.StreakBonus = { [3] = 2, [7] = 5 }
Missions.StreakCycle = 7

local byId = {}
for _, mission in Missions.Pool do
	byId[mission.Id] = mission
end

function Missions.get(id)
	return byId[id]
end

-- Número del día UTC (o el de la hora dada)
function Missions.today(now)
	return math.floor((now or os.time()) / Missions.SECONDS_PER_DAY)
end

-- Segundos que faltan para la medianoche UTC
function Missions.secondsLeft(now)
	now = now or os.time()
	return Missions.SECONDS_PER_DAY - now % Missions.SECONDS_PER_DAY
end

function Missions.text(mission)
	return (string.gsub(mission.Text, "{n}", tostring(mission.Target)))
end

-- Las 3 misiones del jugador ese día (una de cada nivel): siempre las mismas para el mismo jugador y día
function Missions.pick(userId, day)
	local random = Random.new(day * 7919 + (userId % 104729))
	local picked = {}
	for tier = 1, 3 do
		local options = {}
		for _, mission in Missions.Pool do
			if mission.Tier == tier then
				table.insert(options, mission)
			end
		end
		table.insert(picked, options[random:NextInteger(1, #options)])
	end
	return picked
end

-- Lo guardado del día: { day, prog = {n, n, n}, done = {bool, bool, bool} }. Si es de otro día, empieza de cero.
function Missions.normalize(daily, today)
	if typeof(daily) == "table" and daily.day == today and typeof(daily.prog) == "table" and typeof(daily.done) == "table" then
		local prog, done = {}, {}
		for i = 1, 3 do
			prog[i] = typeof(daily.prog[i]) == "number" and daily.prog[i] or 0
			done[i] = daily.done[i] == true
		end
		return { day = today, prog = prog, done = done }
	end
	return { day = today, prog = { 0, 0, 0 }, done = { false, false, false } }
end

-- Racha que se muestra: la cuenta si completó algo ayer o hoy; si no, 0
function Missions.streakCount(streak, today)
	if typeof(streak) == "table" and typeof(streak.last) == "number" and typeof(streak.count) == "number" and streak.last >= today - 1 then
		return streak.count
	end
	return 0
end

-- Suma lo hecho en una ronda (`gains`: { kills = n, revives = n, ... }) a las misiones del día. Devuelve la lista nueva
-- { day, prog, done }, la racha nueva { last, count }, y lo ganado: { rhoms (total), missionRhoms, streakRhoms, completed = {textos} }.
function Missions.apply(userId, daily, streak, today, gains)
	local state = Missions.normalize(daily, today)
	local picked = Missions.pick(userId, today)
	local result = { rhoms = 0, missionRhoms = 0, streakRhoms = 0, completed = {} }
	for i, mission in picked do
		if not state.done[i] then
			state.prog[i] = math.min(mission.Target, state.prog[i] + (gains[mission.Metric] or 0))
			if state.prog[i] >= mission.Target then
				state.done[i] = true
				result.missionRhoms += mission.Rhoms
				table.insert(result.completed, Missions.text(mission))
			end
		end
	end
	local newStreak = typeof(streak) == "table" and { last = streak.last, count = streak.count } or { last = 0, count = 0 }
	if #result.completed > 0 and newStreak.last ~= today then
		newStreak.count = (newStreak.last == today - 1) and (newStreak.count + 1) or 1
		newStreak.last = today
		result.streakRhoms = Missions.StreakBonus[newStreak.count] or 0
		if newStreak.count >= Missions.StreakCycle then
			newStreak.count = 0 -- el ciclo termina; sigue con 1 si juega mañana
		end
	end
	result.rhoms = result.missionRhoms + result.streakRhoms
	return state, newStreak, result
end

return Missions
