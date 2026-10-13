-- Límite de frecuencia para las señales que manda el cliente (Remotes): un jugador (o un tramposo con un script) no puede
-- saturar al servidor repitiendo una acción más rápido de lo razonable. Cada señal tiene su propio intervalo mínimo por
-- jugador; las llamadas más rápidas se descartan sin avisar.
--   RateLimit.check(player, "Clave", 0.25)      true si esta llamada puede pasar (y la anota)
--   RateLimit.wrap("Clave", 0.25, handler)      devuelve un handler(player, ...) que solo llama a `handler` si pasa el límite
local Players = game:GetService("Players")

local RateLimit = {}

local last = {} -- [Player] = { [clave] = os.clock() de la última llamada aceptada }

function RateLimit.check(player, key, interval)
	local now = os.clock()
	local record = last[player]
	if not record then
		record = {}
		last[player] = record
	end
	local previous = record[key]
	if previous and now - previous < interval then
		return false
	end
	record[key] = now
	return true
end

function RateLimit.wrap(key, interval, handler)
	return function(player, ...)
		if RateLimit.check(player, key, interval) then
			handler(player, ...)
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
end)

return RateLimit
