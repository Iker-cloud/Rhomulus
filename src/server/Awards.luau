-- Reconocimientos al final de la partida: "el que más mató", "el que más revivió", "el que más murió"… Se calculan con las estadísticas de
-- server/Stats (nunca con números del cliente) y salen en la pantalla de resultados (Remotes.Results, tercer dato).
-- Cada reconocimiento mira una estadística; lo gana quien más tiene (mínimo `min`). Si empatan dos, lo comparten; si empatan más, no se da.
local Awards = {}

-- id, título, estadística, unidad (singular, plural), mínimo para merecerlo. El orden es la prioridad si hay más de `MAX` ganados.
Awards.List = {
	{ id = "Asesino", title = "THE SLAYER", key = "kills", unit = { "zombie", "zombies" }, min = 1 },
	{ id = "Enfermero", title = "THE MEDIC", key = "revives", unit = { "revive", "revives" }, min = 1 },
	{ id = "Cargador", title = "THE CARRIER", key = "carries", unit = { "carry", "carries" }, min = 1 },
	{ id = "Productivo", title = "MOST PRODUCTIVE", key = "latas", unit = { "can earned", "cans earned" }, min = 50 },
	{ id = "Punteria", title = "GOLDEN AIM", key = "headshots", unit = { "headshot", "headshots" }, min = 3 },
	{ id = "Saco", title = "THE PUNCHING BAG", key = "damage", unit = { "damage taken", "damage taken" }, min = 30 },
	{ id = "Caido", title = "MOST DOWNED", key = "downs", unit = { "time downed", "times downed" }, min = 1 },
	{ id = "Muerto", title = "DIED THE MOST", key = "deaths", unit = { "death", "deaths" }, min = 1 },
	{ id = "Adicto", title = "THE PHIAL ADDICT", key = "phials", unit = { "Phial", "Phials" }, min = 1 },
}
Awards.MAX = 6 -- cuántos salen como mucho en la pantalla

-- `stats` es la lista de Stats.all(). Devuelve { { id, title, winners = { { name, userId } }, value, unit } }
function Awards.compute(stats)
	local result = {}
	for _, award in Awards.List do
		local best, winners = 0, {}
		for _, entry in stats do
			local value = entry[award.key] or 0
			if value > best then
				best, winners = value, { entry }
			elseif value == best and value > 0 then
				table.insert(winners, entry)
			end
		end
		if best >= award.min and #winners >= 1 and #winners <= 2 then
			local people = {}
			for _, entry in winners do
				table.insert(people, { name = entry.name, userId = entry.userId })
			end
			table.insert(result, {
				id = award.id,
				title = award.title,
				winners = people,
				value = best,
				unit = best == 1 and award.unit[1] or award.unit[2],
			})
			if #result >= Awards.MAX then
				break
			end
		end
	end
	return result
end

return Awards
