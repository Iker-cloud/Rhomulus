-- Gestos de los brazos al usar un objeto (granada, molotov, bengala, vendas): fotogramas clave con la posición de cada mano.
-- WeaponAnimator los mezcla con la pose del arma (ver WeaponAnimator.update). El servidor publica en el personaje
-- ItemId, ItemStart e ItemEnd (hora del servidor); aquí el tiempo va de 0 a 1 entre ItemStart e ItemEnd, así que todos los
-- clientes ven el mismo gesto a la vez. Los tiempos (fracciones) deben coincidir con Config.Items.<id>.Anim (Release / End):
-- el objeto sale de la mano en Release.
--
-- Posiciones en el marco de apuntado del jugador, con origen en el pecho y mirando hacia donde mira el cuerpo:
--   x = derecha, y = arriba, z = atrás (el frente es -z). `nil` = la pose normal del arma (entra y sale suave).
-- tilt = cuánto sube (+) o baja (-) la mano, en radianes.
local ItemPoses = {}

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- { fracción de tiempo, posición o nil, inclinación }
local function key(t, pos, tilt)
	return { t = t, pos = pos, tilt = tilt or 0 }
end

local V = Vector3.new

-- Fracciones: dividir el segundo del gesto por Anim.End de Config.Items
local POSES = {
	-- Granada (Release 0.75 de 1.05): la saca al pecho, tira del pasador con la izquierda, se echa hacia atrás y lanza
	Grenade = {
		right = {
			key(0, nil),
			key(0.19, V(0.30, -0.35, -0.85)),
			key(0.36, V(0.30, -0.35, -0.85)),
			key(0.55, V(0.78, 0.40, 0.45), 0.95), -- brazo atrás, por encima del hombro
			key(0.714, V(0.55, 0.45, -1.95), -0.15), -- suelta
			key(0.86, V(0.45, 0.15, -2.25), -0.45), -- sigue el movimiento
			key(1, nil),
		},
		left = {
			key(0, nil),
			key(0.14, V(0.05, -0.30, -0.92)),
			key(0.21, V(0.05, -0.30, -0.92)),
			key(0.36, V(-0.60, -0.50, -0.45)), -- tira del pasador
			key(0.55, V(-0.60, 0.10, -1.30)), -- contrapeso hacia el frente
			key(0.714, V(-0.50, 0.00, -1.00)),
			key(1, nil),
		},
	},
	-- Molotov (Release 0.8 de 1.1): la sube a la altura del pecho, se balancea hacia atrás y la lanza en arco
	Molotov = {
		right = {
			key(0, nil),
			key(0.23, V(0.35, -0.10, -0.90), 0.30),
			key(0.41, V(0.35, -0.10, -0.90), 0.30),
			key(0.56, V(0.70, -0.65, 0.30), -0.45), -- balanceo hacia atrás
			key(0.727, V(0.60, 0.10, -1.90), 0.55), -- suelta con el arco hacia arriba
			key(0.86, V(0.50, 0.40, -2.10), 0.90),
			key(1, nil),
		},
		left = {
			key(0, nil),
			key(0.23, V(-0.20, -0.30, -0.80)),
			key(0.50, V(-0.40, -0.30, -0.70)),
			key(0.727, V(-0.60, 0.00, -1.10)),
			key(1, nil),
		},
	},
	-- Pistola de bengalas (Release 0.7 de 1.1): sube la pistola con las dos manos, apunta, dispara y el retroceso la levanta
	Flare = {
		right = {
			key(0, nil),
			key(0.23, V(0.55, 0.05, -1.30), 0.25),
			key(0.50, V(0.50, 0.10, -1.50), 0.35),
			key(0.636, V(0.50, 0.10, -1.50), 0.35), -- dispara
			key(0.71, V(0.56, 0.28, -1.20), 0.80), -- retroceso
			key(0.86, V(0.50, 0.10, -1.45), 0.40),
			key(1, nil),
		},
		left = {
			key(0, nil),
			key(0.23, V(0.12, -0.05, -1.20)),
			key(0.73, V(0.16, 0.05, -1.00)),
			key(1, nil),
		},
	},
	-- Vendas (Release 1.2 de 1.5): la izquierda se extiende como si fuera el brazo herido y la derecha da vueltas alrededor
	Bandage = {
		right = {
			key(0, nil),
			key(0.14, V(-0.10, -0.45, -1.00), 0.10),
			key(0.80, V(-0.10, -0.45, -1.00), 0.10), -- aquí se suman las vueltas (ver wobble)
			key(1, nil),
		},
		left = {
			key(0, nil),
			key(0.14, V(-0.38, -0.40, -1.15), 0.05),
			key(0.80, V(-0.38, -0.40, -1.15), 0.05),
			key(1, nil),
		},
		-- Vueltas de la mano derecha alrededor de la izquierda mientras dura el vendaje (t en fracción del gesto)
		wobble = function(t)
			if t < 0.14 or t > 0.80 then
				return Vector3.zero
			end
			local phase = (t - 0.14) / (0.80 - 0.14)
			local envelope = math.min(phase / 0.1, (1 - phase) / 0.1, 1)
			local angle = phase * math.pi * 2 * 3 -- tres vueltas
			return V(0.28 * math.sin(angle), 0.20 * math.cos(angle), 0.12 * math.sin(angle * 0.5)) * envelope
		end,
	},
}
-- ¿Hay gesto para este objeto?
ItemPoses.has = function(id)
	return POSES[id] ~= nil
end

-- Interpola una mano. Devuelve (posición o nil, peso 0..1, inclinación): el peso dice cuánto manda el gesto frente a la pose del arma.
local function sampleHand(keys, t)
	local a, b = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if t >= keys[i].t and t <= keys[i + 1].t then
			a, b = keys[i], keys[i + 1]
			break
		end
	end
	local span = b.t - a.t
	local f = span > 0 and smooth((t - a.t) / span) or 1
	if a.pos and b.pos then
		return a.pos:Lerp(b.pos, f), 1, a.tilt + (b.tilt - a.tilt) * f
	elseif b.pos then -- entra desde la pose del arma
		return b.pos, f, b.tilt * f
	elseif a.pos then -- vuelve a la pose del arma
		return a.pos, 1 - f, a.tilt * (1 - f)
	end
	return nil, 0, 0
end

-- t de 0 a 1. Devuelve (posición derecha, peso, inclinación, posición izquierda, peso, inclinación)
function ItemPoses.sample(id, t)
	local poses = POSES[id]
	if not poses then
		return nil, 0, 0, nil, 0, 0
	end
	local rPos, rWeight, rTilt = sampleHand(poses.right, t)
	local lPos, lWeight, lTilt = sampleHand(poses.left, t)
	if rPos and poses.wobble then
		rPos += poses.wobble(t)
	end
	return rPos, rWeight, rTilt, lPos, lWeight, lTilt
end

return ItemPoses
