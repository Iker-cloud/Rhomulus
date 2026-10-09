-- Prueba de acción al revivir (lógica pura, sin estado): crea el aro de una prueba y decide si una pulsación acertó.
-- El cliente (client/SkillCheck) dibuja el aro y la aguja con los mismos números; aquí se juzga con la hora del servidor.
-- Ángulos en grados, desde arriba y hacia la derecha (0..360). La aguja sale en `start` y da una vuelta en `period`.
local SkillCheck = {}

-- Una prueba nueva que empieza `config.Delay` segundos después de `now`
function SkillCheck.new(config, now, index)
	return {
		id = index * 1000 + math.random(0, 999), -- distingue una prueba de otra (y de pulsaciones viejas)
		start = now + config.Delay,
		period = config.Period,
		zoneStart = math.random(config.ZoneMin, config.ZoneMax),
		zoneSize = config.ZoneSize,
		done = false,
	}
end

-- ¿Acertó una pulsación hecha a la hora `pressTime` (hora del servidor, según el cliente)? `now` = hora actual del servidor.
function SkillCheck.judge(check, pressTime, now, config)
	pressTime = math.min(pressTime, now) -- no se aceptan horas del futuro
	local elapsed = pressTime - check.start
	if elapsed < -0.05 or elapsed > check.period + config.Tolerance then
		return false -- demasiado pronto (la aguja no había salido) o demasiado tarde
	end
	local angle = math.clamp(elapsed, 0, check.period) / check.period * 360
	local margin = config.Tolerance / check.period * 360
	return angle >= check.zoneStart - margin and angle <= check.zoneStart + check.zoneSize + margin
end

return SkillCheck
