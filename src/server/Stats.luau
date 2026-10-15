-- Estadísticas de la partida para la pantalla de resultados.
local Stats = {}

local data = {} -- [Player] = { name, Kills, Revives, DamageTaken }

function Stats.reset()
	data = {}
end

function Stats.add(player, key, amount)
	local entry = data[player]
	if not entry then
		entry = { name = player.DisplayName, userId = player.UserId, Kills = 0, Revives = 0, DamageTaken = 0 }
		data[player] = entry
	end
	entry[key] += amount or 1
end

-- Las estadísticas de un jugador (ceros si todavía no hizo nada)
function Stats.get(player)
	return data[player] or { Kills = 0, Revives = 0, DamageTaken = 0 }
end

function Stats.all()
	local list = {}
	for _, entry in data do
		table.insert(list, {
			name = entry.name,
			userId = entry.userId,
			kills = entry.Kills,
			revives = entry.Revives,
			damage = math.floor(entry.DamageTaken),
		})
	end
	return list
end

return Stats
