-- Reconocimientos al final de la partida: "el que más mató", "el que más revivió", "el que más murió"… Se calculan con las estadísticas de
-- server/Stats (nunca con números del cliente) y salen en la pantalla de resultados (Remotes.Results, tercer dato).
-- Cada reconocimiento mira una estadística; lo gana quien más tiene (mínimo `min`). Si empatan dos, lo comparten; si empatan más, no se da.
local Awards = {}

-- id, título, estadística, unidad (singular, plural), mínimo para merecerlo. El orden es la prioridad si hay más de `MAX` ganados.
Awards.List = {
	{ id = "Asesino", title = "EL MÁS ASESINO", key = "kills", unit = { "zombi", "zombis" }, min = 1 },
	{ id = "Enfermero", title = "EL ENFERMERO", key = "revives", unit = { "revivido", "revividos" }, min = 1 },
	{ id = "Cargador", title = "EL CARGADOR", key = "carries", unit = { "carga", "cargas" }, min = 1 },
	{ id = "Productivo", title = "EL MÁS PRODUCTIVO", key = "latas", unit = { "lata ganada", "latas ganadas" }, min = 50 },
	{ id = "Punteria", title = "PUNTERÍA DE ORO", key = "headshots", unit = { "tiro a la cabeza", "tiros a la cabeza" }, min = 3 },
	{ id = "Saco", title = "EL SACO DE BOXEO", key = "damage", unit = { "de daño recibido", "de daño recibido" }, min = 30 },
	{ id = "Caido", title = "EL MÁS CAÍDO", key = "downs", unit = { "caída", "caídas" }, min = 1 },
	{ id = "Muerto", title = "EL QUE MÁS MURIÓ", key = "deaths", unit = { "muerte", "muertes" }, min = 1 },
	{ id = "Adicto", title = "EL ADICTO A LAS PHIALS", key = "phials", unit = { "Phial", "Phials" }, min = 1 },
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
