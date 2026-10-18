-- Estadísticas de la partida para la pantalla de resultados y los reconocimientos (server/Awards).
local Stats = {}

local KEYS = { "Kills", "Revives", "DamageTaken", "Carries", "Downs", "Deaths", "Headshots", "Phials" }

local data = {} -- [Player] = { name, userId, y un contador por cada clave de KEYS }

function Stats.reset()
	data = {}
end

local function newEntry(player)
	local entry = { name = player.DisplayName, userId = player.UserId }
	for _, key in KEYS do
		entry[key] = 0
	end
	return entry
end

function Stats.add(player, key, amount)
	local entry = data[player]
	if not entry then
		entry = newEntry(player)
		data[player] = entry
	end
	entry[key] += amount or 1
end

-- Las estadísticas de un jugador (ceros si todavía no hizo nada)
function Stats.get(player)
	return data[player] or newEntry(player)
end

-- La lista de todos los jugadores con lo que hicieron (latas: lo que ganó el jugador, de Points.add)
function Stats.all()
	local list = {}
	for player, entry in data do
		table.insert(list, {
			name = entry.name,
			userId = entry.userId,
			kills = entry.Kills,
			revives = entry.Revives,
			damage = math.floor(entry.DamageTaken),
			carries = entry.Carries,
			downs = entry.Downs,
			deaths = entry.Deaths,
			headshots = entry.Headshots,
			phials = entry.Phials,
			latas = player.Parent and player:GetAttribute("LatasEarned") or 0,
		})
	end
	return list
end

return Stats
