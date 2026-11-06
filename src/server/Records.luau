-- Récord de extracción rápida por dificultad: el menor tiempo, desde que el equipo sale del lobby hasta que gana, que se ha logrado en
-- cada dificultad (de todos los servidores). Se guarda en el DataStore "RhomulusRecords" (clave run_<dificultad>) con el equipo que lo logró.
-- Si el guardado no está disponible (Studio sin publicar) devuelve solo el tiempo de la partida, sin récord que comparar.
local DataStoreService = game:GetService("DataStoreService")

local Records = {}

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("RhomulusRecords")
	end)
	if ok then
		store = result
	end
end

-- Registra una victoria. Devuelve { difficulty, time, best, bestNames, isRecord } (best nil si no hay guardado)
function Records.submit(difficultyId, seconds, names)
	local info = { difficulty = difficultyId, time = seconds, isRecord = false }
	if not store then
		return info
	end
	local ok, value = pcall(function()
		return store:UpdateAsync("run_" .. difficultyId, function(old)
			if typeof(old) == "table" and typeof(old.time) == "number" and old.time <= seconds then
				return old
			end
			info.isRecord = true
			return { time = seconds, names = names, at = os.time() }
		end)
	end)
	if ok and typeof(value) == "table" then
		info.best = value.time
		info.bestNames = value.names
	end
	return info
end

-- Survival: la oleada más alta que ha aguantado un equipo de `players` jugadores (clave waves_<jugadores>).
-- Devuelve { waves, players, best, bestNames, isRecord } (best nil si no hay guardado)
function Records.submitWaves(players, waves, names)
	local info = { waves = waves, players = players, isRecord = false }
	if not store then
		return info
	end
	local ok, value = pcall(function()
		return store:UpdateAsync("waves_" .. players, function(old)
			if typeof(old) == "table" and typeof(old.waves) == "number" and old.waves >= waves then
				return old
			end
			info.isRecord = true
			return { waves = waves, names = names, at = os.time() }
		end)
	end)
	if ok and typeof(value) == "table" then
		info.best = value.waves
		info.bestNames = value.names
	end
	return info
end

return Records
