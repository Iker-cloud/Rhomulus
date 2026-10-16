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

return Progress
