-- Poses de los brazos al llevar y usar un objeto (granada, molotov, bengala, vendas, botiquín). WeaponAnimator las mezcla con la
-- pose del arma (ver WeaponAnimator.update). Hay tres momentos, todos calculados a partir de atributos del personaje que publica
-- server/Items, así que todos los clientes ven lo mismo a la vez:
--   ready(id, tiempo, pitch)    el objeto en la mano, esperando (con un balanceo suave de respiración)
--   charge(id, fuerza, ...)     el lanzamiento cargándose: de 0 a 1 la mano va de la pose lista a la de "todo atrás"
--   sample(id, t, fuerza, ...)  el gesto de usarlo: t de 0 a 1 entre ItemStart e ItemEnd, empezando donde estaba la carga
-- Las fracciones de las claves deben coincidir con Config.Items.<id>.Anim (Release / End); el objeto sale de la mano en Release.
-- Para el botiquín el gesto dura Config.Medkit.Time (5 s): la tapa se abre al 10 % y se cierra al 88 % (server/Medkits).
--
-- Posiciones en el marco de apuntado del jugador, con origen en el pecho y mirando hacia donde mira el cuerpo:
--   x = derecha, y = arriba, z = atrás (el frente es -z). tilt = cuánto sube (+) o baja (-) la mano, en radianes.
local ItemPoses = {}

local V = Vector3.new
local START = {} -- en las claves del gesto: "donde estaba la mano al empezar" (la pose de la carga)

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function key(t, pos, tilt)
	return { t = t, pos = pos, tilt = tilt or 0 }
end

-- ready / charge: { r, rt, l, lt } = posición y inclinación de cada mano. follow = cuánto sigue la mano al giro de la cámara arriba/abajo.
local POSES = {
	-- Granada: en el pecho con la izquierda en el pasador; cargada, el brazo derecho se echa atrás por encima del hombro y la
	-- izquierda se estira hacia delante para medir la distancia. Al soltar, el brazo barre hacia delante.
	Grenade = {
		ready = { r = V(0.30, -0.35, -0.85), rt = 0, l = V(0.05, -0.30, -0.92), lt = 0 },
		charge = { r = V(0.78, 0.40, 0.45), rt = 0.95, l = V(-0.45, 0.12, -1.30), lt = 0.25 },
		right = {
			key(0, START),
			key(0.364, V(0.55, 0.45, -1.95), -0.15), -- suelta
			key(0.62, V(0.45, 0.15, -2.25), -0.45), -- sigue el movimiento
			key(1, V(0.40, 0.05, -2.00), -0.35),
		},
		left = {
			key(0, START),
			key(0.364, V(-0.55, 0.00, -1.10)),
			key(1, V(-0.45, -0.20, -0.90)),
		},
	},
	-- Molotov: en el pecho con la izquierda libre; cargado, el brazo se balancea hacia atrás y abajo (lanzamiento de abajo hacia
	-- arriba, en arco) y al soltarlo sube.
	Molotov = {
		ready = { r = V(0.35, -0.10, -0.90), rt = 0.3, l = V(-0.20, -0.30, -0.80), lt = 0 },
		charge = { r = V(0.72, -0.70, 0.35), rt = -0.5, l = V(-0.40, 0.00, -1.20), lt = 0.1 },
		right = {
			key(0, START),
			key(0.385, V(0.60, 0.10, -1.90), 0.55), -- suelta con el arco hacia arriba
			key(0.70, V(0.50, 0.40, -2.10), 0.90),
			key(1, V(0.45, 0.30, -1.90), 0.80),
		},
		left = {
			key(0, START),
			key(0.385, V(-0.50, -0.10, -1.00)),
			key(1, V(-0.40, -0.30, -0.90)),
		},
	},
	-- Pistola de bengalas: a dos manos, baja y lista; al cargar sube el cañón (el arco de la bengala); al soltar dispara y el
	-- retroceso la levanta. La inclinación sigue un poco hacia donde mira la cámara.
	Flare = {
		follow = 0.6,
		ready = { r = V(0.50, -0.20, -1.15), rt = 0.15, l = V(0.15, -0.25, -1.05), lt = 0.1 },
		charge = { r = V(0.50, 0.15, -1.50), rt = 0.9, l = V(0.20, 0.10, -1.30), lt = 0.8 },
		right = {
			key(0, START),
			key(0.2, V(0.56, 0.35, -1.20), 1.25), -- retroceso
			key(0.6, V(0.50, 0.15, -1.45), 0.90),
			key(1, V(0.48, 0.00, -1.40), 0.60),
		},
		left = {
			key(0, START),
			key(0.2, V(0.18, 0.20, -1.10), 0.9),
			key(1, V(0.15, 0.00, -1.15), 0.5),
		},
	},
	-- Vendas (Release 1.3 de 1.6): la izquierda se extiende como el brazo herido y la derecha da vueltas alrededor
	Bandage = {
		ready = { r = V(0.12, -0.45, -0.95), rt = 0.1, l = V(-0.30, -0.45, -1.00), lt = 0.05 },
		right = {
			key(0, START),
			key(0.12, V(-0.10, -0.45, -1.00), 0.10),
			key(0.82, V(-0.10, -0.45, -1.00), 0.10), -- aquí se suman las vueltas (ver wobbleR)
			key(1, V(0.10, -0.40, -1.00), 0.10),
		},
		left = {
			key(0, START),
			key(0.12, V(-0.38, -0.40, -1.15), 0.05),
			key(0.82, V(-0.38, -0.40, -1.15), 0.05),
			key(1, V(-0.30, -0.45, -1.00), 0.05),
		},
		wobbleR = function(t)
			if t < 0.12 or t > 0.82 then
				return Vector3.zero
			end
			local phase = (t - 0.12) / 0.70
			local envelope = math.min(phase / 0.1, (1 - phase) / 0.1, 1)
			local angle = phase * math.pi * 2 * 3 -- tres vueltas
			return V(0.28 * math.sin(angle), 0.20 * math.cos(angle), 0.12 * math.sin(angle * 0.5)) * envelope
		end,
	},
	-- Jeringa de la farmacia (Config.Pharmacy.Anim, 2,8 s): la sube al pecho, extiende el brazo izquierdo con la palma arriba, apoya
	-- la aguja en el antebrazo (0,42), la clava (0,50), empuja el émbolo (0,50 a 0,78), la retira y baja el brazo.
	Syringe = {
		ready = { r = V(0.28, -0.35, -0.90), rt = 0.1, l = V(-0.30, -0.40, -0.95), lt = 0 },
		right = {
			key(0, START),
			key(0.14, V(0.15, 0.05, -0.95), 0.3), -- la sube y mira la aguja
			key(0.30, V(-0.12, 0.38, -0.75), -0.55), -- la lleva sobre el antebrazo
			key(0.42, V(-0.53, 0.43, -0.38), -1.2), -- la aguja toca la piel
			key(0.50, V(-0.53, 0.36, -0.36), -1.2), -- clava
			key(0.78, V(-0.53, 0.36, -0.36), -1.2), -- empuja el émbolo
			key(0.88, V(-0.50, 0.52, -0.42), -1.1), -- la retira
			key(1, V(0.24, -0.38, -0.88), 0.1),
		},
		left = {
			key(0, START),
			key(0.14, V(-0.30, -0.40, -1.00), 0),
			key(0.28, V(-0.40, -0.52, -1.14), 0.05), -- extiende el antebrazo
			key(0.88, V(-0.40, -0.52, -1.14), 0.05),
			key(1, V(-0.30, -0.45, -0.95), 0),
		},
		wobbleL = function(t) -- el brazo aprieta el puño al notar el pinchazo
			if t < 0.5 or t > 0.82 then
				return Vector3.zero
			end
			local phase = (t - 0.5) / 0.32
			return V(0.015 * math.sin(phase * 40), 0.01 * math.sin(phase * 33), 0) * math.min(phase / 0.15, 1)
		end,
	},
	-- Golpes cuerpo a cuerpo (Config.Melee.Duration, 0,5 s; el golpe cae en 0,45): los usa server/Melee con el `Style` de cada skin.
	-- Tajo en diagonal: sube atrás a la derecha y baja cruzando hacia la izquierda.
	MeleeSlash = {
		ready = { r = V(0.30, -0.30, -0.90), rt = 0.3, l = V(-0.25, -0.40, -0.85), lt = 0 },
		right = {
			key(0, START),
			key(0.22, V(0.55, 0.50, -0.55), 1.0), -- arma arriba y atrás
			key(0.45, V(-0.30, -0.15, -1.85), -0.35), -- golpe
			key(0.70, V(-0.55, -0.40, -1.45), -0.55), -- sigue el movimiento
			key(1, V(0.30, -0.30, -0.90), 0.3),
		},
		left = {
			key(0, START),
			key(0.22, V(-0.15, -0.20, -0.85), 0.2),
			key(0.45, V(-0.35, -0.30, -1.10), 0),
			key(1, V(-0.25, -0.40, -0.85), 0),
		},
	},
	-- Golpe desde arriba: las dos manos lo suben sobre la cabeza y lo bajan con fuerza.
	MeleeChop = {
		ready = { r = V(0.25, -0.30, -0.95), rt = 0.3, l = V(-0.10, -0.35, -0.90), lt = 0.1 },
		right = {
			key(0, START),
			key(0.25, V(0.20, 0.90, -0.30), 1.4), -- sobre la cabeza
			key(0.45, V(0.10, -0.40, -1.90), -0.95), -- golpe
			key(0.70, V(0.15, -0.55, -1.60), -0.75),
			key(1, V(0.25, -0.30, -0.95), 0.3),
		},
		left = {
			key(0, START),
			key(0.25, V(0.05, 0.75, -0.40), 1.3),
			key(0.45, V(0.00, -0.45, -1.70), -0.9),
			key(0.70, V(0.00, -0.55, -1.50), -0.7),
			key(1, V(-0.10, -0.35, -0.90), 0.1),
		},
	},
	-- Barrido: el arma va atrás a la derecha y cruza en horizontal hasta la izquierda.
	MeleeSweep = {
		ready = { r = V(0.30, -0.30, -0.90), rt = 0.2, l = V(-0.15, -0.35, -0.90), lt = 0.1 },
		right = {
			key(0, START),
			key(0.22, V(0.90, 0.05, -0.70), 0.5), -- lo echa atrás a la derecha
			key(0.45, V(-0.10, 0.00, -1.80), 0.1), -- golpe al frente
			key(0.70, V(-0.80, -0.05, -1.30), 0.0), -- termina a la izquierda
			key(1, V(0.30, -0.30, -0.90), 0.2),
		},
		left = {
			key(0, START),
			key(0.22, V(0.40, -0.05, -0.85), 0.4),
			key(0.45, V(-0.15, -0.10, -1.50), 0.1),
			key(0.70, V(-0.55, -0.10, -1.20), 0.0),
			key(1, V(-0.15, -0.35, -0.90), 0.1),
		},
	},
	-- Estocada (cuchillo): la mano se recoge a la cadera y se lanza recta hacia delante; la izquierda cubre.
	MeleeStab = {
		ready = { r = V(0.30, -0.30, -0.90), rt = 0.3, l = V(-0.25, -0.40, -0.85), lt = 0 },
		right = {
			key(0, START),
			key(0.20, V(0.40, -0.50, -0.30), 0.55), -- se recoge
			key(0.45, V(0.10, -0.10, -2.10), 0.10), -- clava
			key(0.65, V(0.12, -0.12, -1.95), 0.10),
			key(1, V(0.30, -0.30, -0.90), 0.3),
		},
		left = {
			key(0, START),
			key(0.20, V(-0.35, -0.25, -0.70), 0.1),
			key(0.45, V(-0.50, -0.15, -1.05), 0),
			key(1, V(-0.25, -0.40, -0.85), 0),
		},
	},
	-- Sartenazo: un brazo, desde arriba en diagonal con todo el peso, y rebota un poco al chocar.
	MeleeBash = {
		ready = { r = V(0.30, -0.30, -0.90), rt = 0.3, l = V(-0.25, -0.40, -0.85), lt = 0 },
		right = {
			key(0, START),
			key(0.28, V(0.50, 0.85, -0.40), 1.35), -- por encima del hombro
			key(0.46, V(0.00, -0.30, -1.85), -0.85), -- golpe
			key(0.54, V(0.02, -0.22, -1.70), -0.55), -- rebote
			key(0.74, V(0.05, -0.50, -1.50), -0.70),
			key(1, V(0.30, -0.30, -0.90), 0.3),
		},
		left = {
			key(0, START),
			key(0.28, V(-0.30, -0.10, -0.80), 0.2),
			key(0.46, V(-0.45, -0.30, -1.00), 0),
			key(1, V(-0.25, -0.40, -0.85), 0),
		},
	},
	-- Motosierra: dos manos, la echa atrás a la derecha y la lleva al frente en un barrido bajo; tiembla mientras corta.
	MeleeSaw = {
		ready = { r = V(0.30, -0.35, -0.95), rt = 0.2, l = V(-0.10, -0.40, -1.15), lt = 0.1 },
		right = {
			key(0, START),
			key(0.22, V(0.65, -0.20, -0.75), 0.40),
			key(0.45, V(-0.05, -0.25, -1.90), 0.05), -- entra al frente
			key(0.75, V(-0.40, -0.30, -1.70), 0.00), -- sigue cortando a la izquierda
			key(1, V(0.30, -0.35, -0.95), 0.2),
		},
		left = {
			key(0, START),
			key(0.22, V(0.15, -0.30, -1.00), 0.2),
			key(0.45, V(-0.25, -0.35, -1.55), 0.05),
			key(0.75, V(-0.55, -0.35, -1.35), 0),
			key(1, V(-0.10, -0.40, -1.15), 0.1),
		},
		wobbleR = function(t)
			if t < 0.35 or t > 0.85 then
				return Vector3.zero
			end
			return V(0.022 * math.sin(t * 420), 0.016 * math.sin(t * 370), 0.012 * math.sin(t * 510))
		end,
		wobbleL = function(t)
			if t < 0.35 or t > 0.85 then
				return Vector3.zero
			end
			return V(0.018 * math.sin(t * 390 + 1), 0.014 * math.sin(t * 450), 0.01 * math.sin(t * 330))
		end,
	},
	-- Botiquín (5 s): lo sube al pecho con la derecha, la izquierda abre la tapa, saca gasa y cura (la mano entra y sale del
	-- maletín), y al final cierra la tapa y lo baja.
	Medkit = {
		ready = { r = V(0.32, -0.55, -0.75), rt = 0, l = V(-0.45, -0.65, -0.35), lt = 0 },
		right = {
			key(0, START),
			key(0.08, V(0.20, -0.25, -1.05), 0.45),
			key(0.90, V(0.20, -0.25, -1.05), 0.45),
			key(1, V(0.32, -0.50, -0.85), 0.2),
		},
		left = {
			key(0, START),
			key(0.08, V(-0.30, -0.40, -0.95)),
			key(0.14, V(-0.12, -0.18, -1.20), 0.3), -- sube a levantar la tapa
			key(0.20, V(-0.05, -0.28, -1.10)),
			key(0.84, V(-0.05, -0.28, -1.10)), -- aquí se suman los vaivenes (ver wobbleL)
			key(0.90, V(-0.12, -0.18, -1.20), 0.3), -- baja la tapa
			key(1, V(-0.45, -0.60, -0.40)),
		},
		wobbleL = function(t)
			if t < 0.20 or t > 0.84 then
				return Vector3.zero
			end
			local phase = (t - 0.20) / 0.64
			local envelope = math.min(phase / 0.08, (1 - phase) / 0.08, 1)
			local a = phase * math.pi * 2 * 4 -- cuatro entradas y salidas del maletín
			return V(-0.10 * (1 - math.cos(a)) * 0.5, 0.14 * (1 - math.cos(a)) * 0.5, -0.06 * math.sin(a)) * envelope
		end,
	},
}

function ItemPoses.has(id)
	return POSES[id] ~= nil
end

-- ¿Se lanza (tiene carga)?
function ItemPoses.throwable(id)
	return POSES[id] ~= nil and POSES[id].charge ~= nil
end

local function follow(id, pitch)
	return (POSES[id].follow or 0) * (pitch or 0)
end

-- El objeto en la mano. `now` = tiempo para el balanceo. Devuelve (posición der., inclinación der., posición izq., inclinación izq.)
function ItemPoses.ready(id, now, pitch)
	local p = POSES[id]
	local sway = V(0.012 * math.sin(now * 1.7), 0.014 * math.sin(now * 2.3 + 1), 0.01 * math.sin(now * 1.3))
	local f = follow(id, pitch)
	return p.ready.r + sway, p.ready.rt + f, p.ready.l - sway, p.ready.lt + f
end

-- El lanzamiento cargándose a `power` de 0 a 1 (con un temblor al llegar al máximo)
function ItemPoses.charge(id, power, now, pitch)
	local p = POSES[id]
	if not p.charge then
		return ItemPoses.ready(id, now, pitch)
	end
	local e = smooth(power)
	local shake = power > 0.85 and V(math.sin(now * 53), math.sin(now * 61 + 1), math.sin(now * 47 + 2)) * 0.012 * (power - 0.85) / 0.15 or Vector3.zero
	local f = follow(id, pitch)
	return p.ready.r:Lerp(p.charge.r, e) + shake,
		p.ready.rt + (p.charge.rt - p.ready.rt) * e + f,
		p.ready.l:Lerp(p.charge.l, e) - shake,
		p.ready.lt + (p.charge.lt - p.ready.lt) * e + f
end

-- Interpola una mano. `start` = (posición, inclinación) de partida para las claves START.
local function sampleHand(keys, t, startPos, startTilt)
	local a, b = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if t >= keys[i].t and t <= keys[i + 1].t then
			a, b = keys[i], keys[i + 1]
			break
		end
	end
	local aPos, aTilt = a.pos, a.tilt
	if aPos == START then
		aPos, aTilt = startPos, startTilt
	end
	local span = b.t - a.t
	local f = span > 0 and smooth((t - a.t) / span) or 1
	return aPos:Lerp(b.pos, f), aTilt + (b.tilt - aTilt) * f
end

-- El gesto de usarlo (t de 0 a 1). `power` = lo que se cargó (0 si no se carga). Devuelve (pos der., inclinación der., pos izq., inclinación izq.)
function ItemPoses.sample(id, t, power, now, pitch)
	local p = POSES[id]
	local rPos0, rTilt0, lPos0, lTilt0
	if p.charge then
		rPos0, rTilt0, lPos0, lTilt0 = ItemPoses.charge(id, power or 0, now or 0, 0)
	else
		rPos0, rTilt0, lPos0, lTilt0 = ItemPoses.ready(id, now or 0, 0)
	end
	local rPos, rTilt = sampleHand(p.right, t, rPos0, rTilt0)
	local lPos, lTilt = sampleHand(p.left, t, lPos0, lTilt0)
	if p.wobbleR then
		rPos += p.wobbleR(t)
	end
	if p.wobbleL then
		lPos += p.wobbleL(t)
	end
	local f = follow(id, pitch) * math.max(0, 1 - t * 2) -- el seguimiento de la cámara se va con el gesto
	return rPos, rTilt + f, lPos, lTilt + f
end

return ItemPoses
