-- Progresión del jugador entre partidas: XP, niveles y cómo se calcula el XP de una partida. Lo comparten la partida (que lo reparte
-- y lo guarda) y el menú (que muestra el nivel). Solo es matemática: no guarda nada ni toca al jugador.
local Progress = {}

Progress.MaxLevel = 50

-- XP por cada cosa de la partida. Se multiplica por la dificultad (DifficultyMult). Valores sin balancear: se ajustan con los datos.
Progress.Xp = {
	Kill = 1.5, -- por zombie
	Revive = 25, -- por compañero revivido
	Win = 200, -- bono por ganar
	Finish = 50, -- por jugar la partida hasta el final (aunque se pierda)
}
Progress.DifficultyMult = { Calma = 0.8, Tension = 1, Crisis = 1.3, Colapso = 1.6 }

-- Nivel que hace falta para elegir cada dificultad (Calma y Tensión desde el principio). En una sala basta con que el anfitrión la tenga:
-- los demás juegan la que él eligió.
Progress.UnlockLevel = { Calma = 1, Tension = 1, Crisis = 5, Colapso = 10 }

function Progress.requiredLevel(difficultyId)
	return Progress.UnlockLevel[difficultyId] or 1
end

-- ¿Puede elegir esta dificultad quien lleva `totalXp`? Sin datos (nil: guardado no disponible) se deja elegir cualquiera.
function Progress.isUnlocked(difficultyId, totalXp)
	if totalXp == nil then
		return true
	end
	return (Progress.fromTotal(totalXp)) >= Progress.requiredLevel(difficultyId)
end

-- XP que hace falta para subir de `level` al siguiente
function Progress.needed(level)
	return 250 + 75 * (level - 1)
end

-- De XP total a (nivel, XP dentro del nivel, XP que pide ese nivel). En el nivel máximo `into` y `need` son 0.
function Progress.fromTotal(total)
	total = math.max(0, math.floor(total or 0))
	local level = 1
	while level < Progress.MaxLevel do
		local need = Progress.needed(level)
		if total < need then
			return level, total, need
		end
		total -= need
		level += 1
	end
	return level, 0, 0
end

-- XP de una partida a partir de las estadísticas del jugador (Stats: Kills, Revives). `finished` es si llegó hasta el final.
-- `mutatorBonus` es el XP extra de los mutadores de la ronda (0.45 = +45 %, ver shared/Mutators).
-- Devuelve (xp, desglose) con el desglose { kills, revives, win, finish } ya multiplicado por la dificultad y los mutadores.
function Progress.roundXp(stats, won, finished, difficultyId, mutatorBonus)
	local mult = (Progress.DifficultyMult[difficultyId] or 1) * (1 + (mutatorBonus or 0))
	local parts = {
		kills = math.floor((stats.Kills or 0) * Progress.Xp.Kill * mult + 0.5),
		revives = math.floor((stats.Revives or 0) * Progress.Xp.Revive * mult + 0.5),
		win = won and finished and math.floor(Progress.Xp.Win * mult + 0.5) or 0,
		finish = finished and math.floor(Progress.Xp.Finish * mult + 0.5) or 0,
	}
	return parts.kills + parts.revives + parts.win + parts.finish, parts
end

-- Rhoms: la moneda permanente del jugador (se gasta en el menú). Valores sin balancear.
Progress.Rhoms = {
	Finish = 1, -- por llegar al menos a la zona 2 (aunque se pierda); si no llegan, la ronda no da Rhoms
	Win = 2, -- extra por ganar
	WinByDifficulty = { Crisis = 1, Colapso = 2 }, -- extra por ganar en esa dificultad
	Mutation = 1, -- extra si en la ronda salió una mutación Épica o Legendaria
	Award = 1, -- extra si recibió un reconocimiento al final
}

-- Rhoms de una partida. `rarities` es la lista de rarezas de las mutaciones de la ronda ("Epic", "Legendary"...).
-- Devuelve (total, desglose { finish, win, difficulty, mutation, award }).
function Progress.roundRhoms(won, finished, difficultyId, rarities, hasAward, reachedZone2)
	local cfg = Progress.Rhoms
	local parts = { finish = 0, win = 0, difficulty = 0, mutation = 0, award = 0 }
	if not finished or reachedZone2 == false then
		return 0, parts
	end
	parts.finish = cfg.Finish
	if won then
		parts.win = cfg.Win
		parts.difficulty = cfg.WinByDifficulty[difficultyId] or 0
	end
	for _, rarity in rarities or {} do
		if rarity == "Epic" or rarity == "Legendary" then
			parts.mutation = cfg.Mutation
			break
		end
	end
	if hasAward then
		parts.award = cfg.Award
	end
	return parts.finish + parts.win + parts.difficulty + parts.mutation + parts.award, parts
end

-- Survival: no hay victoria; el XP y los Rhoms salen de las oleadas que aguantó el equipo. Valores sin balancear.
Progress.Survival = {
	MinWaves = 3, -- con menos oleadas la partida no da Rhoms ni el bono de terminar
	XpPerWave = 20,
	RhomsPerWaves = 3, -- 1 Rhom por cada tantas oleadas...
	RhomsCap = 12, -- ...hasta este tope por partida (así no se farmea la tienda)
}

-- Rhoms de una partida de Survival (+1 si recibió un reconocimiento al final)
function Progress.survivalRhoms(waves, hasAward)
	local cfg = Progress.Survival
	if waves < cfg.MinWaves then
		return 0
	end
	return math.min(cfg.RhomsCap, waves // cfg.RhomsPerWaves) + (hasAward and Progress.Rhoms.Award or 0)
end

return Progress
